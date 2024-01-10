// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./GeneralHelper.sol";

// import "forge-std/Test.sol";

//import "forge-std/console.sol";

contract MevHelper {
    mapping(string => uint8) internal functionSigsToJumpLabel;

    constructor() {
        setupSigJumpLabelMapping();
    }

    function v3CreateSandwichPayloadWethIsInput(
        address pool,
        address inputToken,
        address outputToken,
        uint24 fee,
        int256 amountIn
    ) public returns (bytes memory payload, uint256 encodedValue) {
        (address token0, address token1) = inputToken < outputToken
            ? (inputToken, outputToken)
            : (outputToken, inputToken);
        uint amountInActual = (uint256(amountIn) / wethEncodeMultiple()) *
            wethEncodeMultiple();
        uint256 amountOut = GeneralHelper.getAmountOutV3(
            uint256(amountInActual),
            inputToken,
            outputToken,
            fee
        );
        (
            uint256 encodedAmount,
            uint256 encodedByteShift,
            ,

        ) = encodeNumToByteAndOffsetV3(uint256(amountOut), 4);
        console.log("Encoded amount out", encodedAmount);
        bytes32 pairInitHash = keccak256(abi.encode(token0, token1, fee));

        uint8 swapType = _v3FindSwapType(false, true, inputToken, outputToken);
        payload = abi.encodePacked(
            uint8(swapType),
            address(pool),
            uint8(encodedByteShift * 8),
            uint32(encodedAmount),
            pairInitHash
        );
        encodedValue = uint256(amountIn) / wethEncodeMultiple();
    }

    function v3CreateSandwichPayloadWethIsOutput(
        address pool,
        address inputToken,
        address outputToken,
        uint24 fee,
        int256 amountIn
    ) public returns (bytes memory payload, uint256 encodedValue) {
        (address token0, address token1) = inputToken < outputToken
            ? (inputToken, outputToken)
            : (outputToken, inputToken);
        // uint amountInActual = (uint256(amountIn) / wethEncodeMultiple()) * wethEncodeMultiple();
        bytes32 pairInitHash = keccak256(abi.encode(token0, token1, fee));
        (
            uint256 encodedAmountIn,
            uint256 encodedByteShiftIn,
            ,

        ) = encodeNumToByteAndOffsetV3(
                (uint256(amountIn) / wethEncodeMultiple()) *
                    wethEncodeMultiple(),
                4
            );
        uint8 swapType = _v3FindSwapType(false, false, inputToken, outputToken);
        payload = abi.encodePacked(
            uint8(swapType),
            address(pool),
            uint8(encodedByteShiftIn * 8),
            uint32(encodedAmountIn),
            address(inputToken),
            pairInitHash
        );
        uint256 amountOut = GeneralHelper.getAmountOutV3(
            uint256(
                (uint256(amountIn) / wethEncodeMultiple()) *
                    wethEncodeMultiple()
            ),
            inputToken,
            outputToken,
            fee
        );
        encodedValue = amountOut / wethEncodeMultiple();
    }

    function v3CreateSandwichMultiMeatPayloadWethIsInput(
        address pool,
        address inputToken,
        address outputToken,
        uint24 fee,
        int256 amountIn,
        bool isFirstOfPayload
    ) public returns (bytes memory payload, uint256 encodedValue) {
        if (isFirstOfPayload)
            payload = abi.encodePacked(
                functionSigsToJumpLabel["prepare_stack"]
            );
        (address token0, address token1) = inputToken < outputToken
            ? (inputToken, outputToken)
            : (outputToken, inputToken);
        (
            uint256 encodedAmountIn,
            uint256 encodedByteShiftIn,
            uint amountInActual,

        ) = encodeNumToByteAndOffsetV3(uint256(amountIn), 4);
        uint256 amountOut = GeneralHelper.getAmountOutV3(
            uint256(amountInActual),
            inputToken,
            outputToken,
            fee
        );
        (
            uint256 encodedAmountOut,
            uint256 encodedByteShiftOut,
            ,

        ) = encodeNumToByteAndOffsetV3(uint256(amountOut), 5);
        console.log("Amount out", amountOut);
        console.log("Encoded amount out", encodedAmountOut);
        bytes32 pairInitHash = keccak256(abi.encode(token0, token1, fee));

        uint8 swapType = _v3FindSwapType(true, true, inputToken, outputToken);
        payload = abi.encodePacked(
            payload,
            uint8(swapType),
            address(pool),
            uint8(encodedByteShiftIn * 8),
            uint32(encodedAmountIn),
            uint8(encodedByteShiftOut * 8),
            uint40(encodedAmountOut),
            pairInitHash
        );
        encodedValue = 0;
    }

    function v3CreateSandwichMultiMeatPayloadWethIsOutput(
        address pool,
        address inputToken,
        address outputToken,
        uint24 fee,
        int256 amountIn,
        bool isFirstOfPayload
    ) public returns (bytes memory payload, uint256 encodedValue) {
        if (isFirstOfPayload)
            payload = abi.encodePacked(
                functionSigsToJumpLabel["prepare_stack"]
            );
        (address token0, address token1) = inputToken < outputToken
            ? (inputToken, outputToken)
            : (outputToken, inputToken);
        (
            uint256 encodedAmountIn,
            uint256 encodedByteShiftIn,
            uint amountInActual,

        ) = encodeNumToByteAndOffsetV3(uint256(amountIn), 5);
        uint256 amountOut = GeneralHelper.getAmountOutV3(
            uint256(amountInActual),
            inputToken,
            outputToken,
            fee
        );
        (
            uint256 encodedAmountOut,
            uint256 encodedByteShiftOut,
            ,

        ) = encodeNumToByteAndOffsetV3(uint256(amountOut), 4);
        bytes32 pairInitHash = keccak256(abi.encode(token0, token1, fee));

        uint8 swapType = _v3FindSwapType(true, false, inputToken, outputToken);
        payload = abi.encodePacked(
            payload,
            uint8(swapType),
            address(pool),
            uint8(encodedByteShiftOut * 8),
            uint32(encodedAmountOut),
            uint8(encodedByteShiftIn * 8),
            uint40(encodedAmountIn),
            address(inputToken),
            pairInitHash
        );
        encodedValue = 0;
    }

    function _v3FindSwapType(
        bool isMultimeat,
        bool isWethInput,
        address inputToken,
        address outputToken
    ) internal view returns (uint8) {
        if (isWethInput) {
            if (inputToken < outputToken) {
                // weth is input and token0
                if (isMultimeat)
                    return functionSigsToJumpLabel["v3_input0_multi"];
                else return functionSigsToJumpLabel["v3_input0"];
            } else {
                // weth is input and token1
                if (isMultimeat)
                    return functionSigsToJumpLabel["v3_input1_multi"];
                else return functionSigsToJumpLabel["v3_input1"];
            }
        } else {
            if (inputToken < outputToken) {
                // weth is output and token1
                if (isMultimeat)
                    return functionSigsToJumpLabel["v3_output1_multi"];
                else return functionSigsToJumpLabel["v3_output1"];
            } else {
                // weth is output and token0
                if (isMultimeat)
                    return functionSigsToJumpLabel["v3_output0_multi"];
                else return functionSigsToJumpLabel["v3_output0"];
            }
        }
    }

    // Create payload for when weth is input
    function v2CreateSandwichPayloadWethIsInput(
        address otherToken,
        uint256 amountIn
    ) public view returns (bytes memory payload, uint256 encodedValue) {
        // Declare uniswapv2 types
        IUniswapV2Factory univ2Factory = IUniswapV2Factory(
            0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
        );
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        address pair = address(
            IUniswapV2Pair(univ2Factory.getPair(weth, address(otherToken)))
        );

        // Encode amountIn here (so we can use it for next step)
        uint256 amountInActual = (amountIn / wethEncodeMultiple()) *
            wethEncodeMultiple();
        // Get amounts out and encode it
        (
            uint256 encodedAmountOut,
            uint256 encodedByteShift,

        ) = encodeNumToByteAndOffsetV2(
                GeneralHelper.getAmountOutV2(
                    weth,
                    otherToken,
                    address(univ2Factory),
                    amountInActual
                ),
                4
            );

        // Libary function starts here
        uint8 swapType = _v2FindFunctionSig(false, false, true, otherToken);
        uint256 memoryOffset;
        bool isWethToken0 = weth < otherToken;
        if (isWethToken0) memoryOffset = 68 - 4 - encodedByteShift;
        else memoryOffset = 36 - 4 - encodedByteShift;
        payload = abi.encodePacked(
            uint8(swapType), // type of swap to make
            uint8(memoryOffset), // memoryOffset to store amountOut
            address(pair), // univ2 pair
            uint32(encodedAmountOut) // amountOut
        );

        encodedValue = amountIn / wethEncodeMultiple();
    }

    // Create payload for when weth is input
    function v2CreateSandwichPayloadWethIsOutput(
        address otherToken,
        uint256 amountIn
    ) public view returns (bytes memory payload, uint256 encodedValue) {
        // Declare uniswapv2 types
        IUniswapV2Factory univ2Factory = IUniswapV2Factory(
            0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
        );
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        address pair = address(
            IUniswapV2Pair(univ2Factory.getPair(weth, address(otherToken)))
        );

        // Libary function starts here
        uint8 swapType = _v2FindFunctionSig(false, false, false, otherToken);
        // bool isWethToken0 = weth < otherToken;
        // encode amountIn
        (
            uint256 encodedAmountIn,
            uint256 encodedByteShift,

        ) = encodeNumToByteAndOffsetV2(amountIn, 4);
        // with dust
        encodedAmountIn -= 1;
        uint256 amountInActual = encodedAmountIn << (encodedByteShift * 8);

        payload = abi.encodePacked(
            uint8(swapType), // token we're giving
            uint8(68 - 4 - encodedByteShift), // memoryOffset to store amountIn
            address(pair), // univ2 pair
            address(otherToken), // inputToken
            uint32(encodedAmountIn) // amountIn
        );

        uint256 amountOut = GeneralHelper.getAmountOutV2(
            otherToken,
            weth,
            address(univ2Factory),
            amountInActual
        );
        encodedValue = amountOut / wethEncodeMultiple();
    }

    // Create multimeat payload for when weth is input
    function v2CreateSandwichMultiPayloadWethIsInput(
        address otherToken,
        uint256 amountIn,
        bool isFirstOfPayload
    ) public view returns (bytes memory payload, uint256 encodedValue) {
        // Declare uniswapv2 types
        IUniswapV2Factory univ2Factory = IUniswapV2Factory(
            0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
        );
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        address pair = address(
            IUniswapV2Pair(univ2Factory.getPair(weth, address(otherToken)))
        );

        // Encode amountIn here (so we can use it for next step)
        uint256 amountInActual = (amountIn / wethEncodeMultiple()) *
            wethEncodeMultiple();

        // Get amounts out and encode it
        (
            uint256 encodedAmountOut,
            uint256 encodedByteShift,

        ) = encodeNumToByteAndOffsetV2(
                GeneralHelper.getAmountOutV2(
                    weth,
                    otherToken,
                    address(univ2Factory),
                    amountInActual
                ),
                4
            );
        uint encodedAmountIn = amountIn / wethEncodeMultiple();
        // Libary function starts here
        uint8 swapType = _v2FindFunctionSig(
            true,
            isFirstOfPayload,
            true,
            otherToken
        );
        uint256 memoryOffsetOut;
        bool isWethToken0 = weth < otherToken;
        if (isWethToken0) memoryOffsetOut = 68 - 4 - encodedByteShift;
        else memoryOffsetOut = 36 - 4 - encodedByteShift;
        if (isFirstOfPayload) {
            payload = abi.encodePacked(
                uint8(swapType), // type of swap to make
                uint8(memoryOffsetOut), // memoryOffset to store amountOut
                address(pair), // univ2 pair
                uint32(encodedAmountOut) // amountOut
            );
            encodedValue = encodedAmountIn;
        } else {
            payload = abi.encodePacked(
                uint8(swapType), // type of swap to make
                uint8(memoryOffsetOut), // memoryOffset to store amountOut
                address(pair), // univ2 pair
                uint32(encodedAmountOut), // amountOut
                uint40(encodedAmountIn) // amountIn
            );
        }
    }

    // Create multimeat payload for when weth is input
    function v2CreateSandwichMultiPayloadWethIsOutput(
        address otherToken,
        uint256 amountIn,
        bool isFirstOfPayload
    ) public view returns (bytes memory payload, uint256 encodedValue) {
        // Declare uniswapv2 types
        IUniswapV2Factory univ2Factory = IUniswapV2Factory(
            0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
        );
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        address pair = address(
            IUniswapV2Pair(univ2Factory.getPair(weth, address(otherToken)))
        );
        uint256 memoryOffsetOut;
        uint256 memoryOffsetIn;
        bool isWethToken0 = weth < otherToken;
        // Encode amountIn here (so we can use it for next step)
        (
            uint256 encodedAmountIn,
            uint256 encodedByteShiftIn,

        ) = encodeNumToByteAndOffsetV2(amountIn, 4);
        // with dust
        encodedAmountIn -= 1;
        uint256 amountInActual = encodedAmountIn << (encodedByteShiftIn * 8);
        // Get amounts out and encode it
        (
            uint256 encodedAmountOut,
            uint256 encodedByteShiftOut,

        ) = encodeNumToByteAndOffsetV2(
                GeneralHelper.getAmountOutV2(
                    otherToken,
                    weth,
                    address(univ2Factory),
                    amountInActual
                ),
                5
            );
        console.log(encodedByteShiftOut);
        if (isWethToken0) {
            memoryOffsetIn = 68 - encodedByteShiftIn - 4; // calldata for transfer(to,value)
            memoryOffsetOut = 68 - encodedByteShiftOut; // 0x40 + swap(amountout0, amountout1, address(this), "")
        } else {
            memoryOffsetIn = 68 - encodedByteShiftIn - 4; // calldata for transfer(to,value)
            memoryOffsetOut = 100 - encodedByteShiftOut; // 0x40 + swap(amountout0, amountout1, address(this), "")
        }
        // Libary function starts here
        uint8 swapType = _v2FindFunctionSig(
            true,
            isFirstOfPayload,
            false,
            otherToken
        );
        if (isFirstOfPayload) {
            payload = abi.encodePacked(
                uint8(swapType), // type of swap to make
                uint8(memoryOffsetIn), // memoryOffset to store amountIn
                address(pair), // univ2 pair
                address(otherToken), // inputToken
                uint32(encodedAmountIn), // amountIn
                uint8(memoryOffsetOut)
            );
            encodedValue = encodedAmountOut;
        } else {
            payload = abi.encodePacked(
                uint8(swapType), // type of swap to make
                uint8(memoryOffsetIn), // memoryOffset to store amountIn
                address(pair), // univ2 pair
                address(otherToken), // inputToken
                uint32(encodedAmountIn), // amountIn
                uint40(encodedAmountOut), // amountOut
                uint8(memoryOffsetOut) // memoryOffset to store amountOut
            );
        }
    }

    function _v2FindFunctionSig(
        bool isMultimeat,
        bool isFirstOfPayload,
        bool isWethInput,
        address otherToken
    ) internal view returns (uint8) {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        if (isWethInput) {
            if (isMultimeat) {
                if (isFirstOfPayload)
                    return functionSigsToJumpLabel["v2_input_multi_first"];
                else return functionSigsToJumpLabel["v2_input_multi_next"];
            } else return functionSigsToJumpLabel["v2_input_single"];
        } else {
            if (isMultimeat) {
                if (isFirstOfPayload) {
                    return functionSigsToJumpLabel["v2_output_multi_first"];
                } else {
                    return functionSigsToJumpLabel["v2_output_multi_next"];
                }
            } else {
                if (weth < otherToken) {
                    // weth is output and token0
                    return functionSigsToJumpLabel["v2_output0_single"];
                } else {
                    // weth is output and token1
                    return functionSigsToJumpLabel["v2_output1_single"];
                }
            }
        }
    }

    function v2CreateArbitragePayload(
        address inputToken,
        address outputToken,
        address factory,
        bool isTail,
        uint amountIn
    ) public view returns (bytes memory payload, uint encodedAmountOut) {
        uint amountOut = GeneralHelper.getAmountOutV2(
            inputToken,
            outputToken,
            factory,
            amountIn
        );
        (
            uint256 encodedAmount,
            uint256 encodedByteShift,
            uint256 amountAfterEncoding
        ) = encodeNumToByteAndOffsetV2(amountOut, 4);
        uint8 swapType = _v2FindArbFunctionSig(isTail);
        bool isZeroForOne = inputToken < outputToken;
        uint memOffset;
        if(isZeroForOne) {
            memOffset = 68 - 4 - encodedByteShift;
        } else{
            memOffset = 36 - 4 - encodedByteShift;
        }
        address pool = GeneralHelper.getV2Pair(inputToken, outputToken, factory);
        payload = abi.encodePacked(
            uint8(swapType),
            uint8(memOffset),
            address(pool),
            uint32(encodedAmount)
        );
        encodedAmountOut = amountAfterEncoding;
    }

    function _v2FindArbFunctionSig(bool isTail) internal view returns (uint8) {
        if (isTail) {
            return functionSigsToJumpLabel["arbitrage_v2_swap_to_this"];
        } else {
            return functionSigsToJumpLabel["arbitrage_v2_swap_to_other"];
        }
    }

    function encodeNumToByteAndOffsetV2(
        uint256 amount,
        uint256 numBytesToEncodeTo
    )
        public
        pure
        returns (
            uint256 encodedAmount,
            uint256 encodedByteShift,
            uint256 amountAfterEncoding
        )
    {
        for (uint256 i = 0; i < 32; i++) {
            uint256 _encodedAmount = amount / 2 ** (8 * i);

            // If we can fit the value in numBytesToEncodeTo bytes, we can encode it
            if (_encodedAmount <= 2 ** (numBytesToEncodeTo * (8)) - 1) {
                //uint encodedAmount = amountOutAfter * 2**(8*i);
                encodedByteShift = i;
                encodedAmount = _encodedAmount;
                amountAfterEncoding = encodedAmount << (encodedByteShift * 8);
                break;
            }
        }
    }

    function encodeNumToByteAndOffsetV3(
        uint256 amount,
        uint256 numBytesToEncodeTo
    )
        public
        pure
        returns (
            uint256 encodedAmount,
            uint256 encodedByteShift,
            uint256 amountAfterEncoding,
            uint256 memOffset
        )
    {
        for (uint256 i = 0; i < 32; i++) {
            uint256 _encodedAmount = amount / 2 ** (8 * i);

            // If we can fit the value in numBytesToEncodeTo bytes, we can encode it
            if (_encodedAmount <= 2 ** (numBytesToEncodeTo * (8)) - 1) {
                //uint encodedAmount = amountOutAfter * 2**(8*i);
                encodedByteShift = i;
                encodedAmount = _encodedAmount;
                amountAfterEncoding = encodedAmount << (encodedByteShift * 8);
                break;
            }
        }
        encodedByteShift = 32 - numBytesToEncodeTo - encodedByteShift;

        memOffset = 68 - numBytesToEncodeTo - encodedByteShift;
    }

    function wethEncodeMultiple() public pure returns (uint256) {
        return uint256(0x100000000);
    }

    function getJumpLabelFromSig(
        string calldata sig
    ) public view returns (uint8) {
        return functionSigsToJumpLabel[sig];
    }

    function setupSigJumpLabelMapping() private {
        uint256 startingIndex = 0x30;

        string[22] memory functionNames = [
            "v2_input_single",
            "v2_output0_single",
            "v2_output1_single",
            "v3_input0",
            "v3_input1",
            "v3_output0",
            "v3_output1",
            "v2_input_multi_first",
            "v2_input_multi_next",
            "v2_output_multi_first",
            "v2_output_multi_next",
            "prepare_stack",
            "v3_input0_multi",
            "v3_input1_multi",
            "v3_output0_multi",
            "v3_output1_multi",
            "arbitrage_weth_input",
            "arbitrage_v2_swap_to_other",
            "arbitrage_v2_swap_to_this",
            "seppuku",
            "recoverWeth",
            "depositWeth"
        ];

        for (uint256 i = 0; i < functionNames.length; i++) {
            functionSigsToJumpLabel[functionNames[i]] = uint8(
                startingIndex + (0x05 * i)
            );
        }
    }
}
