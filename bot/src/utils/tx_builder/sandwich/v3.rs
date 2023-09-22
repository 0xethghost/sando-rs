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
        let jump_label_names = vec!["v3_input0", "v3_input1", "v3_output0", "v3_output1"];

        let start_offset = 54;

        for x in 0..jump_label_names.len() {
            jump_labels.insert(
                jump_label_names[x].to_string(),
                start_offset + (5 * (x as u32)),
            );
        }

        SandwichLogicV3 { jump_labels }
    }

    // Handles creation of tx data field when weth is input
    pub fn create_payload_weth_is_input(
        &self,
        amount_in: I256,
        input: Address,
        output: Address,
        pool: Pool,
    ) -> (Vec<u8>, U256) {
        let (token_0, token_1, fee) = (pool.token_0, pool.token_1, pool.swap_fee);
        let swap_type = self._find_swap_type(true, input, output);
        let pool_key_hash = ethers::utils::keccak256(abi::encode(&[
            abi::Token::Address(token_0),
            abi::Token::Address(token_1),
            abi::Token::Uint(fee),
        ]));

        let (payload, _) = utils::encode_packed(&[
            utils::PackedToken::NumberWithShift(swap_type, utils::TakeLastXBytes(8)),
            utils::PackedToken::Address(pool.address),
            utils::PackedToken::Bytes(&pool_key_hash),
        ]);

        let encoded_call_value = U256::from(amount_in.as_u128()) / get_weth_encode_divisor();

        (payload, encoded_call_value)
    }

    // Handles creation of tx data field when weth is output
    pub fn create_payload_weth_is_output(
        &self,
        amount_in: I256,
        input: Address,
        output: Address,
        pool: Pool,
    ) -> Vec<u8> {
        let (token_0, token_1, fee) = (pool.token_0, pool.token_1, pool.swap_fee);
        let swap_type = self._find_swap_type(false, input, output);
        let encoded_swap_value = encode_five_bytes(U256::from(amount_in.as_u128()));
        let pool_key_hash = ethers::utils::keccak256(abi::encode(&[
            abi::Token::Address(token_0),
            abi::Token::Address(token_1),
            abi::Token::Uint(fee),
        ]));

        // use small encoding method (encode amount_in to 6 bytes)
        let (payload, _) = utils::encode_packed(&vec![
            utils::PackedToken::NumberWithShift(swap_type, utils::TakeLastXBytes(8)),
            utils::PackedToken::Address(pool.address),
            utils::PackedToken::Address(input),
            utils::PackedToken::Bytes(&pool_key_hash),
            utils::PackedToken::NumberWithShift(encoded_swap_value.byte_shift, utils::TakeLastXBytes(8)),
            utils::PackedToken::NumberWithShift(
                encoded_swap_value.encoded_value,
                utils::TakeLastXBytes(40),
            ),
        ]);

        payload
    }

    // Internal helper function to find correct JUMPDEST
    fn _find_swap_type(&self, is_weth_input: bool, input: Address, output: Address) -> U256 {
        let swap_type: u32 = match (is_weth_input, (input < output)) {
            // weth is input and token0
            (true, true) => self.jump_labels["v3_input0"],
            // weth is input and token1
            (true, false) => self.jump_labels["v3_input1"],
            // weth is output and token0
            (false, true) => self.jump_labels["v3_output0"],
            // weth is output and token1
            (false, false) => self.jump_labels["v3_output1"],
        };

        U256::from(swap_type)
    }
}

// Encode the swap value into number of bytes
//
// Returns:
// EncodedSwapValue representing 5 byte value, and byteshift
fn encode_five_bytes(amount: U256) -> EncodedSwapValue {
    let mut byte_shift = 0;
    let mut encoded_value = U256::zero();

    for i in 0u8..32u8 {
        let _encoded_amount = amount / 2u128.pow(8 * i as u32);

        // if we can fit the value in 4 bytes (0xFFFFFFFF), we can encode it
        if _encoded_amount < U256::from(2).pow(U256::from(5 * 8)) {
            encoded_value = _encoded_amount;
            byte_shift = i;
            break;
        }
    }
    EncodedSwapValue::new(
        encoded_value,
        U256::from(68 - 5 - byte_shift),
        U256::from(byte_shift),
    )
}

/// returns the encoded value of amount in (actual value passed to contract)
pub fn encode_intermediary_token(amount_in: U256) -> U256 {
    let encoded_swap_value = encode_five_bytes(amount_in);
    encoded_swap_value.decode()
}   

/// returns the encoded value of amount in (actual value passed to contract)
pub fn encode_weth(amount_in: U256) -> U256 {
    (amount_in / get_weth_encode_divisor()) * get_weth_encode_divisor()
}
