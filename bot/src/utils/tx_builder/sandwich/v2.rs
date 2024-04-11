use std::ops::{Div, Sub};

use super::*;
use hashbrown::HashMap;

use crate::{prelude::Pool, utils};

#[derive(Debug, Clone)]
pub struct SandwichLogicV2 {
    jump_labels: HashMap<String, u32>,
}

impl SandwichLogicV2 {
    pub fn new() -> Self {
        let mut jump_labels: HashMap<String, u32> = HashMap::new();

        // pattern: {input||output}{isWeth0||isWeth1}_{numBytesToEncodeTo}
        let jump_label_names_single =
            vec!["v2_input_single", "v2_output0_single", "v2_output1_single"];
        let jump_label_names_multi = vec![
            "v2_input_multi_first",
            "v2_input_multi_next",
            "v2_output_multi_first",
            "v2_output_multi_next",
        ];

        let start_offset_single = 48;
        let start_offset_multi = 83;

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

        SandwichLogicV2 { jump_labels }
    }

    pub fn create_payload_weth_is_input(
        &self,
        block_number: U256,
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

        let swap_type = self._find_swap_type(false, false, true, other_token);

        let (payload, _) = utils::encode_packed(&[
            utils::PackedToken::NumberWithShift(block_number, utils::TakeLastXBytes(8)),
            utils::PackedToken::NumberWithShift(swap_type, utils::TakeLastXBytes(8)),
            utils::PackedToken::NumberWithShift(
                encoded_swap_value.mem_offset,
                utils::TakeLastXBytes(8),
            ),
            utils::PackedToken::Address(pair.address),
            utils::PackedToken::NumberWithShift(
                encoded_swap_value.encoded_value,
                utils::TakeLastXBytes(32),
            ),
        ]);

        let encoded_call_value = amount_in.div(get_weth_encode_divisor());
        (payload, encoded_call_value)
    }

    pub fn create_payload_weth_is_output(
        &self,
        block_number: U256,
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

        let swap_type = self._find_swap_type(false, false, false, other_token);

        let (payload, _) = utils::encode_packed(&[
            utils::PackedToken::NumberWithShift(block_number, utils::TakeLastXBytes(8)),
            utils::PackedToken::NumberWithShift(swap_type, utils::TakeLastXBytes(8)),
            utils::PackedToken::NumberWithShift(
                encoded_swap_value.mem_offset,
                utils::TakeLastXBytes(8),
            ),
            utils::PackedToken::Address(pair.address),
            utils::PackedToken::Address(other_token),
            utils::PackedToken::NumberWithShift(
                encoded_swap_value.encoded_value,
                utils::TakeLastXBytes(32),
            ),
        ]);

        let encoded_call_value = amount_out.div(get_weth_encode_divisor());
        // log::info!("{}", format!("[Backrun payload] {:02x?}", payload));
        // log::info!("{}", format!("[Backrun value] {:?}", encoded_call_value));

        (payload, encoded_call_value)
    }

    pub fn create_multi_payload_weth_is_input(
        &self,
        block_number: U256,
        amount_in: U256,
        amount_out: U256,
        other_token: Address, // output token
        pair: Pool,
        is_first: bool,
    ) -> (Vec<u8>, U256) {
        let encoded_amount_out_swap_value = encode_four_bytes(
            amount_out,
            true,
            utils::constants::get_weth_address() < other_token,
        );

        let swap_type = self._find_swap_type(true, is_first, true, other_token);
        let encoded_amount_in = amount_in.div(get_weth_encode_divisor());
        let mut callvalue = U256::from(0);
        let (payload, _) = if is_first {
            callvalue = encoded_amount_in;
            utils::encode_packed(&[
                utils::PackedToken::NumberWithShift(block_number, utils::TakeLastXBytes(8)),
                utils::PackedToken::NumberWithShift(swap_type, utils::TakeLastXBytes(8)),
                utils::PackedToken::NumberWithShift(
                    encoded_amount_out_swap_value.mem_offset,
                    utils::TakeLastXBytes(8),
                ),
                utils::PackedToken::Address(pair.address),
                utils::PackedToken::NumberWithShift(
                    encoded_amount_out_swap_value.encoded_value,
                    utils::TakeLastXBytes(32),
                ),
            ])
        } else {
            utils::encode_packed(&[
                utils::PackedToken::NumberWithShift(block_number, utils::TakeLastXBytes(8)),
                utils::PackedToken::NumberWithShift(swap_type, utils::TakeLastXBytes(8)),
                utils::PackedToken::NumberWithShift(
                    encoded_amount_out_swap_value.mem_offset,
                    utils::TakeLastXBytes(8),
                ),
                utils::PackedToken::Address(pair.address),
                utils::PackedToken::NumberWithShift(
                    encoded_amount_out_swap_value.encoded_value,
                    utils::TakeLastXBytes(32),
                ),
                utils::PackedToken::NumberWithShift(encoded_amount_in, utils::TakeLastXBytes(40)),
            ])
        };

        (payload, callvalue)
    }

    pub fn create_multi_payload_weth_is_output(
        &self,
        block_number: U256,
        amount_in: U256,
        amount_out: U256,
        other_token: Address, // output token
        pair: Pool,
        is_first: bool,
    ) -> (Vec<u8>, U256) {
        let encoded_amount_out_swap_value = encode_five_bytes(
            amount_out,
            utils::constants::get_weth_address() < other_token,
        );

        let swap_type = self._find_swap_type(true, is_first, false, other_token);
        let encoded_amount_in_swap_value = encode_four_bytes(
            amount_in,
            false,
            utils::constants::get_weth_address() < other_token,
        );
        let mut callvalue = U256::from(0);
        let (payload, _) = if is_first {
            callvalue = encoded_amount_out_swap_value.encoded_value;
            utils::encode_packed(&[
                utils::PackedToken::NumberWithShift(block_number, utils::TakeLastXBytes(8)),
                utils::PackedToken::NumberWithShift(swap_type, utils::TakeLastXBytes(8)),
                utils::PackedToken::NumberWithShift(
                    encoded_amount_in_swap_value.mem_offset,
                    utils::TakeLastXBytes(8),
                ),
                utils::PackedToken::Address(pair.address),
                utils::PackedToken::Address(other_token),
                utils::PackedToken::NumberWithShift(
                    encoded_amount_in_swap_value.encoded_value,
                    utils::TakeLastXBytes(32),
                ),
                utils::PackedToken::NumberWithShift(
                    encoded_amount_out_swap_value.mem_offset,
                    utils::TakeLastXBytes(8),
                ),
            ])
        } else {
            utils::encode_packed(&[
                utils::PackedToken::NumberWithShift(block_number, utils::TakeLastXBytes(8)),
                utils::PackedToken::NumberWithShift(swap_type, utils::TakeLastXBytes(8)),
                utils::PackedToken::NumberWithShift(
                    encoded_amount_in_swap_value.mem_offset,
                    utils::TakeLastXBytes(8),
                ),
                utils::PackedToken::Address(pair.address),
                utils::PackedToken::Address(other_token),
                utils::PackedToken::NumberWithShift(
                    encoded_amount_in_swap_value.encoded_value,
                    utils::TakeLastXBytes(32),
                ),
                utils::PackedToken::NumberWithShift(
                    encoded_amount_out_swap_value.encoded_value,
                    utils::TakeLastXBytes(40),
                ),
                utils::PackedToken::NumberWithShift(
                    encoded_amount_out_swap_value.mem_offset,
                    utils::TakeLastXBytes(8),
                ),
            ])
        };

        (payload, callvalue)
    }

    fn _find_swap_type(
        &self,
        is_multiple: bool,
        is_first_of_payload: bool,
        is_weth_input: bool,
        other_token_addr: Address,
    ) -> U256 {
        let weth_addr = utils::constants::get_weth_address();

        let swap_type = if is_multiple {
            match (is_first_of_payload, is_weth_input) {
                (true, true) => self.jump_labels["v2_input_multi_first"],
                (false, true) => self.jump_labels["v2_input_multi_next"],
                (true, false) => self.jump_labels["v2_output_multi_first"],
                (false, false) => self.jump_labels["v2_output_multi_next"],
            }
        } else {
            match (is_weth_input, weth_addr < other_token_addr) {
                (true, _) => self.jump_labels["v2_input_single"],
                (false, true) => self.jump_labels["v2_output0_single"],
                (false, false) => self.jump_labels["v2_output1_single"],
            }
        };

        U256::from(swap_type)
    }
}

// Encode the swap value into 4 bytes
//
// Returns:
// EncodedSwapValue representing 4 byte value, and byteshift
fn encode_four_bytes(amount: U256, is_weth_input: bool, is_weth_token0: bool) -> EncodedSwapValue {
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

// Encode the swap value into 4 bytes
//
// Returns:
// EncodedSwapValue representing 4 byte value, and byteshift
fn encode_five_bytes(amount: U256, is_weth_token0: bool) -> EncodedSwapValue {
    let mut byte_shift = 0;
    let mut five_byte_encoded_value = U256::zero();

    for i in 0u8..32u8 {
        let _encoded_amount = amount / 2u128.pow(8 * i as u32);

        // if we can fit the value in 4 bytes (0xFFFFFFFF), we can encode it
        if _encoded_amount <= U256::from(2).pow(U256::from(5 * 8).sub(1)) {
            five_byte_encoded_value = _encoded_amount;
            byte_shift = i;
            break;
        }
    }

    let mem_offset = if is_weth_token0 {
        68 - byte_shift
    } else {
        100 - byte_shift
    };

    EncodedSwapValue::new(
        five_byte_encoded_value,
        U256::from(mem_offset),
        U256::from(byte_shift),
    )
}

/// Makes sure that we keep some token dust on contract
pub fn encode_intermediary_token(
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
    // to save gas fee when calling SSTORE
    backrun_in.encoded_value -= U256::from(1);
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
