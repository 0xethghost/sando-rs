use crate::{prelude::Pool, utils};

use super::*;

use hashbrown::HashMap;

#[derive(Debug, Clone)]
pub struct SandwichLogicV3 {
    jump_labels: HashMap<String, u32>,
}

impl SandwichLogicV3 {
    // Create a new `SandwichLogicV3` instance
    pub fn new() -> Self {
        let mut jump_labels: HashMap<String, u32> = HashMap::new();

        // encachement: turn this into a macro or constant?
        let jump_label_names_single = vec!["v3_input0", "v3_input1", "v3_output0", "v3_output1"];
        let jump_label_names_multi = vec![
            "v3_multi_pre",
            "v3_input0_multi",
            "v3_input1_multi",
            "v3_output0_multi",
            "v3_output1_multi",
        ];
        let start_offset_single = 54;
        let start_offset_multi = 94;

        for x in 0..jump_label_names_single.len() {
            jump_labels.insert(
                jump_label_names_single[x].to_string(),
                start_offset_single + (5 * (x as u32)),
            );
        }

        for x in 0..jump_label_names_multi.len() {
            jump_labels.insert(
                jump_label_names_multi[x].to_string(),
                start_offset_multi + (5 * (x as u32)),
            );
        }

        SandwichLogicV3 { jump_labels }
    }

    // Handles creation of tx data field when weth is input
    pub fn create_payload_weth_is_input(
        &self,
        amount_in: I256,
        amount_out: I256,
        input: Address,
        output: Address,
        pool: Pool,
    ) -> (Vec<u8>, U256) {
        let (token_0, token_1, fee) = (pool.token_0, pool.token_1, pool.swap_fee);
        let swap_type = self._find_swap_type(false, true, input, output);
        let pool_key_hash = ethers::utils::keccak256(abi::encode(&[
            abi::Token::Address(token_0),
            abi::Token::Address(token_1),
            abi::Token::Uint(fee),
        ]));
        let encoded_swap_value: EncodedSwapValue =
            encode_num_bytes(U256::from(amount_out.as_u128()), 5);

        let (payload, _) = utils::encode_packed(&[
            utils::PackedToken::NumberWithShift(swap_type, utils::TakeLastXBytes(8)),
            utils::PackedToken::Address(pool.address),
            utils::PackedToken::NumberWithShift(
                U256::from((32 - 5 - encoded_swap_value.byte_shift.as_u64()) * 8),
                utils::TakeLastXBytes(8),
            ),
            utils::PackedToken::NumberWithShift(
                encoded_swap_value.encoded_value,
                utils::TakeLastXBytes(40),
            ),
            utils::PackedToken::Bytes(&pool_key_hash),
        ]);

        let encoded_call_value = U256::from(amount_in.as_u128()) / get_weth_encode_divisor();

        (payload, encoded_call_value)
    }

    // Handles creation of tx data field when weth is output
    pub fn create_payload_weth_is_output(
        &self,
        amount_in: I256,
        amount_out: I256,
        input: Address,
        output: Address,
        pool: Pool,
    ) -> (Vec<u8>, U256) {
        let (token_0, token_1, fee) = (pool.token_0, pool.token_1, pool.swap_fee);
        let swap_type = self._find_swap_type(false, false, input, output);
        let encoded_swap_value = encode_num_bytes(U256::from(amount_in.as_u128()), 5);
        let pool_key_hash = ethers::utils::keccak256(abi::encode(&[
            abi::Token::Address(token_0),
            abi::Token::Address(token_1),
            abi::Token::Uint(fee),
        ]));

        // use small encoding method (encode amount_in to 6 bytes)
        let (payload, _) = utils::encode_packed(&vec![
            utils::PackedToken::NumberWithShift(swap_type, utils::TakeLastXBytes(8)),
            utils::PackedToken::Address(pool.address),
            utils::PackedToken::NumberWithShift(
                U256::from((32 - 5 - encoded_swap_value.byte_shift.as_u64()) * 8),
                utils::TakeLastXBytes(8),
            ),
            utils::PackedToken::NumberWithShift(
                encoded_swap_value.encoded_value,
                utils::TakeLastXBytes(40),
            ),
            utils::PackedToken::Address(input),
            utils::PackedToken::Bytes(&pool_key_hash),
        ]);
        let encoded_call_value = U256::from(amount_out.as_u128()) / get_weth_encode_divisor();

        (payload, encoded_call_value)
    }

    pub fn create_multi_payload_weth_is_input(
        &self,
        amount_in: I256,
        amount_out: I256,
        input: Address,
        output: Address,
        pool: Pool,
        is_first: bool,
    ) -> (Vec<u8>, U256) {
        let (token_0, token_1, fee) = (pool.token_0, pool.token_1, pool.swap_fee);
        let swap_type = self._find_swap_type(true, true, input, output);
        let pool_key_hash = ethers::utils::keccak256(abi::encode(&[
            abi::Token::Address(token_0),
            abi::Token::Address(token_1),
            abi::Token::Uint(fee),
        ]));
        let encoded_amount_in_swap_value: EncodedSwapValue =
            encode_num_bytes(U256::from(amount_in.as_u128()), 4);
        let encoded_amount_out_swap_value: EncodedSwapValue =
            encode_num_bytes(U256::from(amount_out.as_u128()), 5);

        let v3_multi_pre_sig = self.jump_labels["v3_input0_multi"];
        let (payload_data, str_payload) = utils::encode_packed(&[
            utils::PackedToken::NumberWithShift(swap_type, utils::TakeLastXBytes(8)),
            utils::PackedToken::Address(pool.address),
            utils::PackedToken::NumberWithShift(
                U256::from((32 - 4 - encoded_amount_out_swap_value.byte_shift.as_u64()) * 8),
                utils::TakeLastXBytes(8),
            ),
            utils::PackedToken::NumberWithShift(
                encoded_amount_out_swap_value.encoded_value,
                utils::TakeLastXBytes(32),
            ),
            utils::PackedToken::NumberWithShift(
                U256::from((32 - 5 - encoded_amount_in_swap_value.byte_shift.as_u64()) * 8),
                utils::TakeLastXBytes(8),
            ),
            utils::PackedToken::NumberWithShift(
                encoded_amount_in_swap_value.encoded_value,
                utils::TakeLastXBytes(40),
            ),
            utils::PackedToken::Bytes(&pool_key_hash),
        ]);
        let (payload, _) = if is_first {
            utils::encode_packed(&[
                utils::PackedToken::NumberWithShift(
                    U256::from(v3_multi_pre_sig),
                    utils::TakeLastXBytes(8),
                ),
                utils::PackedToken::Bytes(&payload_data),
            ])
        } else {
            (payload_data, str_payload)
        };
        // let encoded_call_value = U256::from(amount_in.as_u128()) / get_weth_encode_divisor();

        (payload, U256::zero())
    }
    pub fn create_multi_payload_weth_is_output(
        &self,
        amount_in: I256,
        amount_out: I256,
        input: Address,
        output: Address,
        pool: Pool,
        is_first: bool,
    ) -> (Vec<u8>, U256) {
        let (token_0, token_1, fee) = (pool.token_0, pool.token_1, pool.swap_fee);
        let swap_type = self._find_swap_type(true, false, input, output);
        let pool_key_hash = ethers::utils::keccak256(abi::encode(&[
            abi::Token::Address(token_0),
            abi::Token::Address(token_1),
            abi::Token::Uint(fee),
        ]));
        let encoded_amount_in_swap_value: EncodedSwapValue =
            encode_num_bytes(U256::from(amount_in.as_u128()), 4);
        let encoded_amount_out_swap_value: EncodedSwapValue =
            encode_num_bytes(U256::from(amount_out.as_u128()), 5);

        let v3_multi_pre_sig = self.jump_labels["v3_input0_multi"];
        let (payload_data, str_payload) = utils::encode_packed(&[
            utils::PackedToken::NumberWithShift(swap_type, utils::TakeLastXBytes(8)),
            utils::PackedToken::Address(pool.address),
            utils::PackedToken::NumberWithShift(
                U256::from((32 - 4 - encoded_amount_out_swap_value.byte_shift.as_u64()) * 8),
                utils::TakeLastXBytes(8),
            ),
            utils::PackedToken::NumberWithShift(
                encoded_amount_out_swap_value.encoded_value,
                utils::TakeLastXBytes(32),
            ),
            utils::PackedToken::NumberWithShift(
                U256::from((32 - 5 - encoded_amount_in_swap_value.byte_shift.as_u64()) * 8),
                utils::TakeLastXBytes(8),
            ),
            utils::PackedToken::NumberWithShift(
                encoded_amount_in_swap_value.encoded_value,
                utils::TakeLastXBytes(40),
            ),
            utils::PackedToken::Bytes(&pool_key_hash),
        ]);
        let (payload, _) = if is_first {
            utils::encode_packed(&[
                utils::PackedToken::NumberWithShift(
                    U256::from(v3_multi_pre_sig),
                    utils::TakeLastXBytes(8),
                ),
                utils::PackedToken::Bytes(&payload_data),
            ])
        } else {
            (payload_data, str_payload)
        };
        // let encoded_call_value = U256::from(amount_in.as_u128()) / get_weth_encode_divisor();

        (payload, U256::zero())
    }

    // Internal helper function to find correct JUMPDEST
    fn _find_swap_type(
        &self,
        is_multiple: bool,
        is_weth_input: bool,
        input: Address,
        output: Address,
    ) -> U256 {
        let swap_type: u32 = if is_multiple {
            match (is_weth_input, (input < output)) {
                // weth is input and token0
                (true, true) => self.jump_labels["v3_input0_multi"],
                // weth is input and token1
                (true, false) => self.jump_labels["v3_input1_multi"],
                // weth is output and token0
                (false, true) => self.jump_labels["v3_output1_multi"],
                // weth is output and token1
                (false, false) => self.jump_labels["v3_output0_multi"],
            }
        } else {
            match (is_weth_input, (input < output)) {
                // weth is input and token0
                (true, true) => self.jump_labels["v3_input0"],
                // weth is input and token1
                (true, false) => self.jump_labels["v3_input1"],
                // weth is output and token0
                (false, true) => self.jump_labels["v3_output1"],
                // weth is output and token1
                (false, false) => self.jump_labels["v3_output0"],
            }
        };

        U256::from(swap_type)
    }
}

// Encode the swap value into number of bytes
//
// Returns:
// EncodedSwapValue representing 5 byte value, and byteshift
fn encode_num_bytes(amount: U256, num_bytes: u8) -> EncodedSwapValue {
    let mut byte_shift = 0;
    let mut encoded_value = U256::zero();

    for i in 0u8..32u8 {
        let _encoded_amount = amount / 2u128.pow(8 * i as u32);

        // if we can fit the value in 4 bytes (0xFFFFFFFF), we can encode it
        if _encoded_amount < U256::from(2).pow(U256::from(num_bytes * 8)) {
            encoded_value = _encoded_amount;
            byte_shift = i;
            break;
        }
    }
    EncodedSwapValue::new(
        encoded_value,
        U256::from(68 - num_bytes - byte_shift),
        U256::from(byte_shift),
    )
}

/// returns the encoded value of amount in (actual value passed to contract)
pub fn encode_intermediary_token(amount_in: U256) -> U256 {
    let backrun_in = encode_num_bytes(amount_in, 5);
    // makes sure that we keep some dust
    // backrun_in.encoded_value -= U256::from(1);
    backrun_in.decode()
}

pub fn decode_intermediary(amount_in: U256) -> U256 {
    let encoded = encode_num_bytes(amount_in, 5);
    encoded.decode()
}

/// returns the encoded value of amount in (actual value passed to contract)
pub fn encode_weth(amount_in: U256) -> U256 {
    (amount_in / get_weth_encode_divisor()) * get_weth_encode_divisor()
}
