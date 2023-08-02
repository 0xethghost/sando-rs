use std::ops::{Sub, Div};

use super::*;
use hashbrown::HashMap;

use crate::{prelude::Pool, utils};

#[derive(Debug, Clone)]
pub struct SandwichLogicV2 {
    jump_labels: HashMap<String, u32>,
}

/// Encoded swap value used by other token
pub struct EncodedSwapValue {
    four_byte_value: U256,
    mem_offset: U256,
    // real value after encoding
    byte_shift: U256,
}

impl EncodedSwapValue {
    fn new(four_byte_value: U256, mem_offset: U256, byte_shift: U256) -> Self {
        Self {
            four_byte_value,
            mem_offset,
            byte_shift,
        }
    }

    // returns the decoded value after applying byteshift (real value used during swaps)
    fn decode(&self) -> U256 {
        self.four_byte_value * (U256::from(2).pow(U256::from(8) * self.byte_shift))
    }
}

impl SandwichLogicV2 {
    pub fn new() -> Self {
        let mut jump_labels: HashMap<String, u32> = HashMap::new();

        // pattern: {input||output}{isWeth0||isWeth1}_{numBytesToEncodeTo}
        let jump_label_names = vec!["v2_output0", "v2_input0", "v2_output1", "v2_input1"];

        let start_offset = 5;

        for x in 0..jump_label_names.len() {
            jump_labels.insert(
                jump_label_names[x].to_string(),
                start_offset + (5 * (x as u32)),
            );
        }

        SandwichLogicV2 { jump_labels }
    }

    pub fn create_payload_weth_is_input(
        &self,
        amount_in: U256,
        amount_out: U256,
        other_token: Address, // output token
        pair: Pool,
    ) -> (Vec<u8>, U256) {
        let encoded_swap_value = encode_four_bytes(
            amount_out,
            true,
            utils::constants::get_weth_address() < other_token,
        );

        let swap_type = self._find_swap_type(true, other_token);

        let (payload, _) = utils::encode_packed(&[
            utils::PackedToken::NumberWithShift(swap_type, utils::TakeLastXBytes(8)),
            utils::PackedToken::NumberWithShift(
                encoded_swap_value.mem_offset,
                utils::TakeLastXBytes(8),
            ),
            utils::PackedToken::Address(pair.address),
            utils::PackedToken::NumberWithShift(
                encoded_swap_value.four_byte_value,
                utils::TakeLastXBytes(32),
            ),
        ]);

        let encoded_call_value = amount_in.div(get_weth_encode_divisor());
        log::info!("{}", format!("[payload] {:?}", payload));
        (payload, encoded_call_value)
    }

    pub fn create_payload_weth_is_output(
        &self,
        amount_in: U256,      // backrun_in
        amount_out: U256,     // backrun_out
        other_token: Address, // input_token
        pair: Pool,
    ) -> (Vec<u8>, U256) {
        let encoded_swap_value = encode_four_bytes(
            amount_in,
            false,
            utils::constants::get_weth_address() < other_token,
        );

        let swap_type = self._find_swap_type(false, other_token);

        let (payload, _) = utils::encode_packed(&[
            utils::PackedToken::NumberWithShift(swap_type, utils::TakeLastXBytes(8)),
            utils::PackedToken::NumberWithShift(
                encoded_swap_value.mem_offset,
                utils::TakeLastXBytes(8),
            ),
            utils::PackedToken::Address(pair.address),
            utils::PackedToken::Address(other_token),
            utils::PackedToken::NumberWithShift(
                encoded_swap_value.four_byte_value,
                utils::TakeLastXBytes(32),
            ),
        ]);

        let encoded_call_value = amount_out.div(get_weth_encode_divisor());

        (payload, encoded_call_value)
    }

    fn _find_swap_type(&self, is_weth_input: bool, other_token_addr: Address) -> U256 {
        let weth_addr = utils::constants::get_weth_address();

        let swap_type = match (is_weth_input, weth_addr < other_token_addr) {
            (true, true) => self.jump_labels["v2_input0"],
            (true, false) => self.jump_labels["v2_input1"],
            (false, true) => self.jump_labels["v2_output0"],
            (false, false) => self.jump_labels["v2_output1"],
        };

        U256::from(swap_type)
    }
}

// Encode the swap value into 4 bytes
//
// Returns:
// EncodedSwapValue representing 4 byte value, and byteshift
pub fn encode_four_bytes(
    amount: U256,
    is_weth_input: bool,
    is_weth_token0: bool,
) -> EncodedSwapValue {
    let mut byte_shift = 0;
    let mut four_byte_encoded_value = U256::zero();

    for i in 0u8..32u8 {
        let _encoded_amount = amount / 2u128.pow(8 * i as u32);

        // if we can fit the value in 4 bytes (0xFFFFFFFF), we can encode it
        if _encoded_amount <= U256::from(2).pow(U256::from(4 * 8).sub(1)) {
            four_byte_encoded_value = _encoded_amount;
            byte_shift = i;
            break;
        }
    }

    match (is_weth_input, is_weth_token0) {
        // memory offset calculated using 4 + 32 + 32 - 4
        (false, _) => EncodedSwapValue::new(
            four_byte_encoded_value,
            U256::from(64 - byte_shift),
            U256::from(byte_shift),
        ),
        // memory offset calculated using 4 + 32 + 32 - 4
        (true, true) => EncodedSwapValue::new(
            four_byte_encoded_value,
            U256::from(64 - byte_shift),
            U256::from(byte_shift),
        ),
        // memory offset calculated using 4 + 32 - 4
        (true, false) => EncodedSwapValue::new(
            four_byte_encoded_value,
            U256::from(32 - byte_shift),
            U256::from(byte_shift),
        ),
    }
}

/// Makes sure that we keep some token dust on contract
pub fn encode_intermediary_with_dust(
    amount_in: U256,
    is_weth_input: bool,
    intermediary_address: Address,
) -> U256 {
    let mut backrun_in = encode_four_bytes(
        amount_in,
        is_weth_input,
        utils::constants::get_weth_address() < intermediary_address,
    );

    // makes sure that we keep some dust
    backrun_in.four_byte_value -= U256::from(1);
    backrun_in.decode()
}

/// returns the real amount after encoding + decoding
/// we lose some byte due to rounding whilst encoding
pub fn decode_intermediary(
    amount_in: U256,
    is_weth_input: bool,
    intermediary_address: Address,
) -> U256 {
    let encoded = encode_four_bytes(
        amount_in,
        is_weth_input,
        utils::constants::get_weth_address() < intermediary_address,
    );
    encoded.decode()
}

/// returns the encoded value of amount in (actual value passed to contract)
pub fn encode_weth(amount_in: U256) -> U256 {
    (amount_in / get_weth_encode_divisor()) * get_weth_encode_divisor()
}
