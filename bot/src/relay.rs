use std::sync::Arc;

use crate::utils;
use ethers::prelude::*;
use ethers_flashbots::*;
use reqwest::Url;

pub struct BundleRelay {
    pub flashbots_client:
        SignerMiddleware<FlashbotsMiddleware<Arc<Provider<Ws>>, LocalWallet>, LocalWallet>,
    pub relay_name: String,
}

impl BundleRelay {
    pub fn new(
        relay_end_point: Url,
        relay_name: String,
        client: &Arc<Provider<Ws>>,
    ) -> Result<BundleRelay, url::ParseError> {
        // Extract wallets from .env keys
        let bundle_private_key = std::env::var("FLASHBOTS_AUTH_KEY").unwrap();
        let searcher_private_key = std::env::var("SEARCHER_PRIVATE_KEY").unwrap();

        let bundle_signer = bundle_private_key.parse::<LocalWallet>().unwrap();
        let searcher_signer = searcher_private_key.parse::<LocalWallet>().unwrap();

        // Setup the Ethereum client with flashbots middleware
        let flashbots_middleware =
            FlashbotsMiddleware::new(client.clone(), relay_end_point, bundle_signer);

        // Local node running mev-geth
        //flashbots_middleware.set_simulation_relay(Url::parse("http://127.0.0.1:8546").unwrap());
        let flashbots_client = SignerMiddleware::new(flashbots_middleware, searcher_signer);

        Ok(BundleRelay {
            flashbots_client,
            relay_name,
        })
    }
}

pub fn construct_bundle(
    signed_txs: Vec<Bytes>,
    target_block: U64, // Current block number
    target_timestamp: u64,
) -> BundleRequest {
    // Create ethers-flashbots bundle request
    let mut bundle_request = BundleRequest::new();

    for tx in signed_txs {
        bundle_request = bundle_request.push_transaction(tx);
    }

    // Set other bundle parameters
    bundle_request = bundle_request
        .set_block(target_block)
        .set_simulation_block(target_block - 1)
        .set_simulation_timestamp(target_timestamp)
        .set_min_timestamp(target_timestamp)
        .set_max_timestamp(target_timestamp);

    bundle_request
}

pub async fn get_all_relay_endpoints() -> Vec<BundleRelay> {
    let client = utils::create_websocket_client().await.unwrap();

    let endpoints = vec![
        ("builder0x69", "https://builder0x69.io/"),
        ("rsync-builder", "https://rsync-builder.xyz/"),
        ("beaverbuild", "https://rpc.beaverbuild.org/"),
        ("titanbuilder", "https://rpc.titanbuilder.xyz"),
        ("flashbots", "https://relay.flashbots.net/"),
        ("eth-builder", "https://eth-builder.com/"),
        // ("lightspeedbuilder", "https://rpc.lightspeedbuilder.info/"),
        ("gambitlabs", "https://builder.gmbit.co/rpc"),
        // ("bloxroute", "https://mev.api.blxrbdn.com"),
        ("boba-builder", "https://boba-builder.com/searcher"),
        ("nfactorial", "https://rpc.nfactorial.xyz"),
        ("buildAI", "https://buildai.net"),
        ("payload", "https://rpc.payload.de"),
    ];

    let mut relays: Vec<BundleRelay> = vec![];

    for (name, endpoint) in endpoints {
        let relay = BundleRelay::new(Url::parse(endpoint).unwrap(), name.into(), &client).unwrap();
        relays.push(relay);
    }

    relays
}
