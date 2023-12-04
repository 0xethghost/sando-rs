use colored::Colorize;
use dashmap::DashMap;
use ethers::prelude::*;
// use ethers::types::transaction::eip2930::AccessList;
use ethers::types::TransactionRequest;
use std::sync::Arc;
// use std::thread;
use std::time::Duration;
use tokio::sync::RwLock;

use crate::prelude::{sync_dex, BlockInfo, Dex, Pool};
use crate::types::BlockOracle;
use crate::utils;
use crate::utils::tx_builder::SandwichMaker;

use super::bundle_sender::BundleSender;
use super::state::BotState;

// Update latest block variable whenever we recieve a new block
//
// Arguments:
// * `oracle`: oracle to update
pub fn start_block_oracle(oracle: &mut Arc<RwLock<BlockOracle>>, sandwich_state: Arc<BotState>) {
    let next_block_clone = oracle.clone();

    tokio::spawn(async move {
        // loop so we can reconnect if the websocket connection is lost
        loop {
            let client = utils::create_websocket_client().await.unwrap();

            let mut block_stream = if let Ok(stream) = client.subscribe_blocks().await {
                stream
            } else {
                panic!("Failed to create new block stream");
            };

            while let Some(block) = block_stream.next().await {
                // lock the RwLock for write access and update the variable
                {
                    let mut write_lock = next_block_clone.write().await;
                    write_lock.update_block_number(block.number.unwrap());
                    write_lock.update_block_timestamp(block.timestamp);
                    write_lock.update_base_fee(block);

                    let latest_block = &write_lock.latest_block;
                    let next_block = &write_lock.next_block;
                    log::info!(
                    "{}",
                    format!(
                        "New Block: (number: {:?}, timestamp: {:?}, basefee: {:?}), Next Block: (number: {:?}, timestamp: {:?}, basefee: {:?})",
                        latest_block.number, latest_block.timestamp, latest_block.base_fee, next_block.number, next_block.timestamp, next_block.base_fee
                    )
                    .bright_purple()
                    .on_black()
                    );
                } // remove write lock due to being out of scope here
                {
                    let sandwich_balance = {
                        let read_lock = sandwich_state.weth_balance.read().await;
                        (*read_lock).clone()
                    };
                    if sandwich_balance > U256::from(4500000000000000000u128) {
                        let sandwich_address = utils::dotenv::get_sandwich_contract_address();
                        let searcher_wallet = utils::dotenv::get_searcher_wallet();
                        // let nonce = utils::get_nonce(&client, searcher_wallet.address())
                        //     .await
                        //     .unwrap();
                        let recover_amount = U256::from(500000000000000000i64);
                        let (payload, value) = get_recover_weth_payload_value(recover_amount);
                        let tx = TransactionRequest::new()
                            .to(NameOrAddress::Address(sandwich_address))
                            .value(value)
                            .from(searcher_wallet.address())
                            .data(payload.clone());
                        // let recover_weth_tx_request = Eip1559TransactionRequest {
                        //     to: Some(NameOrAddress::Address(sandwich_address)),
                        //     from: Some(searcher_wallet.address()),
                        //     data: Some(payload.clone().into()),
                        //     chain_id: Some(U64::from(1)),
                        //     max_priority_fee_per_gas: Some(U256::from(0)),
                        //     max_fee_per_gas: Some(next_block.base_fee),
                        //     gas: Some(U256::from(70000)), // gasused = 70% gaslimit
                        //     nonce: Some(nonce),
                        //     value: Some(value),
                        //     access_list: AccessList::default(),
                        // };
                        // let signed_raw_tx =
                        //     utils::sign_eip1559(recover_weth_tx_request, &searcher_wallet)
                        //         .await
                        //         .unwrap();
                        let pending_tx = client.send_transaction(tx, None).await.unwrap();
                        log::info!(
                            "{}",
                            format!(
                                "Recover weth transaction {:x?}",
                                hex::encode(pending_tx.tx_hash().as_bytes())
                            )
                            .black()
                            .on_white()
                        );
                        // let receipt = pending_tx.await.unwrap().unwrap();
                    }
                }
            }
        }
    });
}

fn get_recover_weth_payload_value(recover_amount: U256) -> (Vec<u8>, U256) {
    let swap_type = U256::from(124);
    let (payload, _) = utils::encode_packed(&[utils::PackedToken::NumberWithShift(
        swap_type,
        utils::TakeLastXBytes(8),
    )]);
    let value = recover_amount / utils::tx_builder::sandwich::get_weth_encode_divisor();
    (payload, value)
}

pub fn start_add_new_pools(all_pools: &mut Arc<DashMap<Address, Pool>>, dexes: Vec<Dex>) {
    let all_pools = all_pools.clone();

    tokio::spawn(async move {
        // loop so we can reconnect if the websocket connection is lost
        loop {
            let client = utils::create_websocket_client().await.unwrap();

            let mut block_stream = if let Ok(stream) = client.subscribe_blocks().await {
                stream
            } else {
                panic!("Failed to create new block stream");
            };

            let mut counter = 0;
            let mut current_block_num = client.get_block_number().await.unwrap();

            while let Some(block) = block_stream.next().await {
                counter += 1;

                let interval_block_new_pool = utils::dotenv::get_interval_block_new_pool();
                if counter == interval_block_new_pool {
                    let latest_block_number = block.number.unwrap();
                    let fetched_new_pools = sync_dex(
                        dexes.clone(),
                        &client,
                        latest_block_number,
                        Some(BlockNumber::Number(current_block_num)),
                    )
                    .await
                    .unwrap();

                    let fetched_pools_count = fetched_new_pools.len();

                    // turn fetched pools into hashmap
                    for pool in fetched_new_pools {
                        // Create hashmap from our vec
                        all_pools.insert(pool.address, pool);
                    }

                    counter = 0;
                    current_block_num = latest_block_number;
                    log::info!("added {} new pools", fetched_pools_count);
                }
            }
        }
    });
}

pub fn start_mega_sandwich_oracle(
    bundle_sender: Arc<RwLock<BundleSender>>,
    sandwich_state: Arc<BotState>,
    sandwich_maker: Arc<SandwichMaker>,
) {
    tokio::spawn(async move {
        // loop so we can reconnect if the websocket connection is lost
        loop {
            let client = utils::create_websocket_client().await.unwrap();

            let mut block_stream = if let Ok(stream) = client.subscribe_blocks().await {
                stream
            } else {
                panic!("Failed to create new block stream");
            };
            while let Some(block) = block_stream.next().await {
                //update searcher nonce
                sandwich_maker.update_searcher_nonce().await;
                // clear all recipes
                // enchanement: don't do this step but keep recipes because they can be used in future
                {
                    let bundle_sender = bundle_sender.clone();
                    let mut bundle_sender_guard = bundle_sender.write().await;
                    bundle_sender_guard.pending_sandwiches.clear();
                } // lock removed here

                // 10.5 seconds from when new block was detected, caluclate mega sandwich
                tokio::time::sleep(Duration::from_millis(10_500)).await;
                let next_block_info = BlockInfo::find_next_block_info(block);
                {
                    let bundle_sender = bundle_sender.clone();
                    bundle_sender
                        .write()
                        .await
                        .make_mega_sandwich(
                            next_block_info,
                            sandwich_state.clone(),
                            sandwich_maker.clone(),
                        )
                        .await;
                } // lock removed here
            }
        }
    });
}
