// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./GeneralHelper.sol";

// import "forge-std/Test.sol";

//import "forge-std/console.sol";

contract SandwichHelper {
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

        ) = encodeNumToByteAndOffsetV3(uint256(amountOut), 5);
        console.log("Encoded amount out", encodedAmount);
        bytes32 pairInitHash = keccak256(abi.encode(token0, token1, fee));

        uint8 swapType = _v3FindSwapType(false, true, inputToken, outputToken);
        payload = abi.encodePacked(
            uint8(swapType),
            address(pool),
            uint8(encodedByteShift * 8),
            uint40(encodedAmount),
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
            uint256 encodedAmount,
            uint256 encodedByteShift,
            ,

        ) = encodeNumToByteAndOffsetV3(
                (uint256(amountIn) / wethEncodeMultiple()) *
                    wethEncodeMultiple(),
                5
            );
        uint8 swapType = _v3FindSwapType(false, false, inputToken, outputToken);
        payload = abi.encodePacked(
            uint8(swapType),
            address(pool),
            uint8(encodedByteShift * 8),
            uint40(encodedAmount),
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
            payload = abi.encodePacked(functionSigsToJumpLabel["v3_multi_pre"]);
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
            payload = abi.encodePacked(functionSigsToJumpLabel["v3_multi_pre"]);
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
            uint256 memoryOffset,

        ) = encodeNumToByteAndOffsetV2(
                GeneralHelper.getAmountOut(weth, otherToken, amountInActual),
                4,
                true,
                weth < otherToken
            );

        // Libary function starts here
        uint8 swapType = _v2FindFunctionSig(true, otherToken);

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
        uint8 swapType = _v2FindFunctionSig(false, otherToken);

        // encode amountIn
        (
            uint256 encodedAmountIn,
            uint256 memoryOffset,
            uint256 amountInActual
        ) = encodeNumToByteAndOffsetV2(amountIn, 4, false, weth < otherToken);

        payload = abi.encodePacked(
            uint8(swapType), // token we're giving
            uint8(memoryOffset), // memoryOffset to store amountIn
            address(pair), // univ2 pair
            address(otherToken), // inputToken
            uint32(encodedAmountIn) // amountIn
        );

        uint256 amountOut = GeneralHelper.getAmountOut(
            otherToken,
            weth,
            amountInActual
        );
        encodedValue = amountOut / wethEncodeMultiple();
    }

    // Create multimeat payload for when weth is input
    function v2CreateSandwichMultiPayloadWethIsInput(
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
            uint256 memoryOffset,

        ) = encodeNumToByteAndOffsetV2(
                GeneralHelper.getAmountOut(weth, otherToken, amountInActual),
                4,
                true,
                weth < otherToken
            );

        // Libary function starts here
        uint8 swapType = _v2FindFunctionSig(true, otherToken);

        payload = abi.encodePacked(
            uint8(swapType), // type of swap to make
            uint8(memoryOffset), // memoryOffset to store amountOut
            address(pair), // univ2 pair
            uint32(encodedAmountOut) // amountOut
        );

        encodedValue = amountIn / wethEncodeMultiple();
    }

    function _v2FindFunctionSig(
        bool isWethInput,
        address otherToken
    ) internal view returns (uint8 encodeAmount) {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        if (isWethInput) {
            return functionSigsToJumpLabel["v2_input_single"];
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

    function encodeNumToByteAndOffsetV2(
        uint256 amount,
        uint256 numBytesToEncodeTo,
        bool isWethInput,
        bool isWethToken0
    )
        public
        pure
        returns (
            uint256 encodedAmount,
            uint256 encodedByteOffset,
            uint256 amountAfterEncoding
        )
    {
        for (uint256 i = 0; i < 32; i++) {
            uint256 _encodedAmount = amount / 2 ** (8 * i);

            // If we can fit the value in numBytesToEncodeTo bytes, we can encode it
            if (_encodedAmount <= 2 ** (numBytesToEncodeTo * (8)) - 1) {
                //uint encodedAmount = amountOutAfter * 2**(8*i);
                encodedByteOffset = i;
                encodedAmount = _encodedAmount;
                amountAfterEncoding = encodedAmount << (encodedByteOffset * 8);
                break;
            }
        }

        if (!isWethInput) {
            // find byte placement for Transfer(address,uint256)
            encodedByteOffset = 68 - numBytesToEncodeTo - encodedByteOffset;
        } else {
            if (isWethToken0) {
                encodedByteOffset = 68 - numBytesToEncodeTo - encodedByteOffset; // V2_Swap_Sig 0 amountOut
            } else {
                encodedByteOffset = 36 - numBytesToEncodeTo - encodedByteOffset; // V2_Swap_Sig amountOut 0
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
        uint256 startingIndex = 0x27;

        string[19] memory functionNames = [
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
            "v3_multi_pre",
            "v3_input0_multi",
            "v3_input1_multi",
            "v3_output0_multi",
            "v3_output1_multi",
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
