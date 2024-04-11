// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "foundry-huff/HuffDeployer.sol";
import "./helpers/GeneralHelper.sol";
import "./helpers/MevHelper.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import "./interfaces/IERC20.sol";
import "v3-core/interfaces/IUniswapV3Pool.sol";

contract SandwichTest is Test {
    address binance8 = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    // serachers
    address constant searcher = 0x56272d28c6087752136b8b72C4fCC2993Ca5c4eF;

    address sandwich;
    MevHelper mevHelper;
    IWETH weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address uniswapV2Factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address shibaV2Factory = 0x115934131916C8b277DD010Ee02de363c09d037c;
    uint256 wethFundAmount = 1000000000 ether;

    struct V3Meat {
        address pool;
        address faucet;
        int256 amountIn;
        bool isFirstOfPayload;
    }

    struct V2Meat {
        address intermediateToken;
        address faucet;
        uint256 amountIn;
        bool isWethToken0;
        bool isFirstOfPayload;
    }

    struct V2Path {
        address inputToken;
        address outputToken;
        address factory;
    }

    function setUp() public {
        mevHelper = new MevHelper();
        sandwich = HuffDeployer.deploy("sandwich");

        // fund sandwich
        weth.deposit{value: wethFundAmount}();
        weth.transfer(sandwich, wethFundAmount);

        // charge for gas fee
        payable(searcher).transfer(100 ether);
    }

    function testV2Weth0Input() public {
        address outputToken = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // Tether
        uint256 amountIn = 1.94212341234123424 ether;

        // Pre swap checks
        uint256 wethBalanceBefore = weth.balanceOf(sandwich);
        uint256 usdtBalanceBefore = IERC20(outputToken).balanceOf(sandwich);

        uint256 actualAmountIn = (amountIn / mevHelper.wethEncodeMultiple()) *
            mevHelper.wethEncodeMultiple();
        uint256 amountOutFromEncoded = GeneralHelper.getAmountOutV2(
            address(weth),
            outputToken,
            uniswapV2Factory,
            actualAmountIn
        );
        (, , uint256 expectedAmountOut) = mevHelper.encodeNumToByteAndOffsetV2(
            amountOutFromEncoded,
            4
        );

        (bytes memory payload, uint256 encodedValue) = mevHelper
            .v2CreateSandwichPayloadWethIsInput(outputToken, amountIn);
        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload);
        emit log_bytes(payload);
        emit log_uint(encodedValue);
        vm.startPrank(searcher);
        uint checkpointGasLeft = gasleft();
        (bool s, ) = address(sandwich).call{value: encodedValue}(payload);
        uint checkpointGasLeft1 = gasleft();
        console.log(
            "testV2WethInput0 gas used:",
            checkpointGasLeft - checkpointGasLeft1
        );
        assertTrue(s);
        vm.stopPrank();

        // Check values after swap
        uint256 wethBalanceChange = wethBalanceBefore -
            weth.balanceOf(sandwich);
        uint256 usdtBalanceChange = IERC20(outputToken).balanceOf(sandwich) -
            usdtBalanceBefore;

        assertEq(
            usdtBalanceChange,
            expectedAmountOut,
            "did not get expected usdt amount out from swap"
        );
        assertEq(
            wethBalanceChange,
            actualAmountIn,
            "unexpected amount of weth used in swap"
        );
    }

    function testV2Weth1Input() public {
        address outputToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        uint256 amountIn = 0.942 ether;

        // Pre swap checks
        uint256 wethBalanceBefore = weth.balanceOf(sandwich);
        uint256 usdcBalanceBefore = IERC20(outputToken).balanceOf(sandwich);

        uint256 actualAmountIn = (amountIn / mevHelper.wethEncodeMultiple()) *
            mevHelper.wethEncodeMultiple();
        uint256 amountOutFromEncoded = GeneralHelper.getAmountOutV2(
            address(weth),
            outputToken,
            uniswapV2Factory,
            actualAmountIn
        );
        (, , uint256 expectedAmountOut) = mevHelper.encodeNumToByteAndOffsetV2(
            amountOutFromEncoded,
            4
        );

        (bytes memory payload, uint256 encodedValue) = mevHelper
            .v2CreateSandwichPayloadWethIsInput(outputToken, amountIn);
        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload);
        emit log_bytes(payload);
        vm.startPrank(searcher);
        uint checkpointGasLeft = gasleft();
        (bool s, ) = address(sandwich).call{value: encodedValue}(payload);
        uint checkpointGasLeft1 = gasleft();
        console.log(
            "testV2WethInput1 gas used:",
            checkpointGasLeft - checkpointGasLeft1
        );
        assertTrue(s);
        vm.stopPrank();

        // Check values after swap
        uint256 wethBalanceChange = wethBalanceBefore -
            weth.balanceOf(sandwich);
        uint256 usdcBalanceChange = IERC20(outputToken).balanceOf(sandwich) -
            usdcBalanceBefore;

        assertEq(
            usdcBalanceChange,
            expectedAmountOut,
            "did not get expected usdc amount out from swap"
        );
        assertEq(
            wethBalanceChange,
            actualAmountIn,
            "unexpected amount of weth used in swap"
        );
    }

    function testV2Weth0Output() public {
        address inputToken = 0xe53EC727dbDEB9E2d5456c3be40cFF031AB40A55; // superfarm
        uint256 amountIn = 1000000 * 10 ** 18;

        // Fund sandwich
        vm.prank(binance8);
        IERC20(inputToken).transfer(sandwich, amountIn);

        // Pre swap checks
        uint256 wethBalanceBefore = weth.balanceOf(sandwich);
        uint256 superFarmBalanceBefore = IERC20(inputToken).balanceOf(sandwich);

        (uint256 encodedAmountIn, uint256 encodedByteShiftIn, ) = mevHelper
            .encodeNumToByteAndOffsetV2(superFarmBalanceBefore, 4);
        // intermediary token with dust
        encodedAmountIn -= 1;
        uint256 actualAmountIn = encodedAmountIn << (encodedByteShiftIn * 8);
        uint256 amountOutFromEncoded = GeneralHelper.getAmountOutV2(
            inputToken,
            address(weth),
            uniswapV2Factory,
            actualAmountIn
        );
        uint256 expectedAmountOut = (amountOutFromEncoded /
            mevHelper.wethEncodeMultiple()) * mevHelper.wethEncodeMultiple();

        // Perform swap
        (bytes memory payload, uint256 encodedValue) = mevHelper
            .v2CreateSandwichPayloadWethIsOutput(
                inputToken,
                superFarmBalanceBefore
            );
        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload);
        emit log_bytes(payload);
        emit log_uint(encodedValue);
        vm.startPrank(searcher);
        uint checkpointGasLeft = gasleft();
        (bool s, ) = address(sandwich).call{value: encodedValue}(payload);
        uint checkpointGasLeft1 = gasleft();
        console.log(
            "testV2WethOutput0 gas used:",
            checkpointGasLeft - checkpointGasLeft1
        );
        assertTrue(s, "swap failed");
        vm.stopPrank();

        // Check values after swap
        uint256 wethBalanceChange = weth.balanceOf(sandwich) -
            wethBalanceBefore;
        uint256 superFarmBalanceChange = superFarmBalanceBefore -
            IERC20(inputToken).balanceOf(sandwich);

        assertEq(
            wethBalanceChange,
            expectedAmountOut,
            "did not get expected weth amount out from swap"
        );
        assertEq(
            superFarmBalanceChange,
            actualAmountIn,
            "unexpected amount of superFarm used in swap"
        );
    }

    function testV2Weth1Output() public {
        address inputToken = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // Dai
        uint256 amountIn = 4722.366481770134 ether; // encoded as 0xFFFFFFFF0000000000

        console.log("amountIn:", amountIn);

        // Fund sandwich
        vm.prank(0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503);
        IERC20(inputToken).transfer(sandwich, amountIn);

        // Pre swap checks
        uint256 wethBalanceBefore = weth.balanceOf(sandwich);
        uint256 daiBalanceBefore = IERC20(inputToken).balanceOf(sandwich);

        (uint256 encodedAmountIn, uint256 encodedByteShiftIn, ) = mevHelper
            .encodeNumToByteAndOffsetV2(daiBalanceBefore, 4);
        // intermediary token with dust
        encodedAmountIn -= 1;
        uint256 actualAmountIn = encodedAmountIn << (encodedByteShiftIn * 8);
        uint256 amountOutFromEncoded = GeneralHelper.getAmountOutV2(
            inputToken,
            address(weth),
            uniswapV2Factory,
            actualAmountIn
        );
        uint256 expectedAmountOut = (amountOutFromEncoded /
            mevHelper.wethEncodeMultiple()) * mevHelper.wethEncodeMultiple();

        // Perform swap
        (bytes memory payload, uint256 encodedValue) = mevHelper
            .v2CreateSandwichPayloadWethIsOutput(inputToken, daiBalanceBefore);
        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload);
        emit log_bytes(payload);
        emit log_uint(encodedValue);
        emit log_uint(amountOutFromEncoded);
        vm.startPrank(searcher);
        uint checkpointGasLeft = gasleft();
        (bool s, ) = address(sandwich).call{value: encodedValue}(payload);
        uint checkpointGasLeft1 = gasleft();
        console.log(
            "testV2WethOutput1 gas used:",
            checkpointGasLeft - checkpointGasLeft1
        );
        assertTrue(s, "swap failed");
        vm.stopPrank();

        // Check values after swap
        uint256 wethBalanceChange = weth.balanceOf(sandwich) -
            wethBalanceBefore;
        uint256 daiBalanceChange = daiBalanceBefore -
            IERC20(inputToken).balanceOf(sandwich);

        assertEq(
            wethBalanceChange,
            expectedAmountOut,
            "did not get expected weth amount out from swap"
        );
        assertEq(
            daiBalanceChange,
            actualAmountIn,
            "unexpected amount of dai used in swap"
        );
    }

    function testV2MultiMeatInput() public {
        V2Meat[2] memory meats = [
            V2Meat(
                0xdAC17F958D2ee523a2206206994597C13D831ec7,
                address(0),
                1.94212341234123424 ether,
                true,
                true
            ),
            V2Meat(
                0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                address(0),
                0.942 ether,
                false,
                false
            )
        ];
        bytes memory payload;
        uint256 callvalue;
        for (uint i = 0; i < meats.length; i++) {
            (bytes memory subPayload, uint encodedValue) = mevHelper
                .v2CreateSandwichMultiPayloadWethIsInput(
                    meats[i].intermediateToken,
                    meats[i].amountIn,
                    meats[i].isFirstOfPayload
                );
            callvalue += encodedValue;
            payload = abi.encodePacked(payload, subPayload);
        }
        uint8 end = 0x2e;
        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload, end);
        emit log_bytes(payload);
        vm.prank(searcher, searcher);
        (bool s, ) = address(sandwich).call{value: callvalue}(payload);
        assertTrue(s, "calling v2 weth input multimeat swap failed");
    }

    function testV2MultiMeatOutput() public {
        V2Meat[2] memory meats = [
            V2Meat(
                0xe53EC727dbDEB9E2d5456c3be40cFF031AB40A55,
                binance8,
                1000000 ether,
                true,
                true
            ),
            V2Meat(
                0x6B175474E89094C44Da98b954EedeAC495271d0F,
                0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503,
                4722.366481770134 ether,
                false,
                false
            )
        ];
        bytes memory payload;
        uint256 callvalue;
        for (uint i = 0; i < meats.length; i++) {
            address inputToken = meats[i].intermediateToken;
            vm.prank(meats[i].faucet);
            IERC20(inputToken).transfer(sandwich, uint256(meats[i].amountIn));
            (bytes memory subPayload, uint encodedValue) = mevHelper
                .v2CreateSandwichMultiPayloadWethIsOutput(
                    meats[i].intermediateToken,
                    meats[i].amountIn,
                    meats[i].isFirstOfPayload
                );
            callvalue += encodedValue;
            payload = abi.encodePacked(payload, subPayload);
        }
        emit log_uint(callvalue);
        uint8 end = 0x2e;
        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload, end);
        emit log_bytes(payload);
        vm.prank(searcher, searcher);
        (bool s, ) = address(sandwich).call{value: callvalue}(payload);
        assertTrue(s, "calling v2 weth input multimeat swap failed");
    }

    function testV3Weth0Input() public {
        address pool = 0x7379e81228514a1D2a6Cf7559203998E20598346; // ETH - STETH
        (address token0, address token1, uint24 fee) = GeneralHelper
            .getV3PoolInfo(pool);
        int256 amountIn = 1.2345678912341234 ether;

        (address outputToken, address inputToken) = (token1, token0);

        (bytes memory payload, uint256 encodedValue) = mevHelper
            .v3CreateSandwichPayloadWethIsInput(
                pool,
                inputToken,
                outputToken,
                fee,
                amountIn
            );
        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload);
        emit log_bytes(payload);
        emit log_uint(encodedValue);

        vm.prank(searcher, searcher);
        (bool s, ) = address(sandwich).call{value: encodedValue}(payload);

        assertTrue(s, "calling swap failed");
    }

    function testV3Weth1Input() public {
        address pool = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640; // USDC - WETH
        (address token0, address token1, uint24 fee) = GeneralHelper
            .getV3PoolInfo(pool);
        int256 amountIn = 1.2345678912341234 ether;

        (address inputToken, address outputToken) = (token1, token0);

        (bytes memory payload, uint256 encodedValue) = mevHelper
            .v3CreateSandwichPayloadWethIsInput(
                pool,
                inputToken,
                outputToken,
                fee,
                amountIn
            );

        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload);

        vm.prank(searcher, searcher);
        (bool s, ) = address(sandwich).call{value: encodedValue}(payload);

        assertTrue(s, "calling swap failed");
    }

    function testV3Weth0OutputSmall() public {
        address pool = 0x7379e81228514a1D2a6Cf7559203998E20598346; // ETH - STETH
        (address token0, address token1, uint24 fee) = GeneralHelper
            .getV3PoolInfo(pool);
        int256 amountIn = 1e16;

        (address inputToken, address outputToken) = (token1, token0);

        // fund sandwich contract
        vm.startPrank(0x56556075Ab3e2Bb83984E90C52850AFd38F20883);
        IERC20(inputToken).transfer(sandwich, uint256(amountIn));

        (bytes memory payload, uint256 encodedValue) = mevHelper
            .v3CreateSandwichPayloadWethIsOutput(
                pool,
                inputToken,
                outputToken,
                fee,
                amountIn
            );

        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload);
        emit log_bytes(payload);

        changePrank(searcher, searcher);
        (bool s, ) = address(sandwich).call{value: encodedValue}(payload);
        assertTrue(s, "v3 swap failed");
    }

    function testV3Weth0OutputBig() public {
        address pool = 0x64A078926AD9F9E88016c199017aea196e3899E1;
        (address token0, address token1, uint24 fee) = GeneralHelper
            .getV3PoolInfo(pool);
        (address inputToken, address outputToken) = (token1, token0);

        int256 amountIn = 100000 ether; // 100000 btt

        // fund sandwich contract
        vm.startPrank(0xD249942f6d417CbfdcB792B1229353B66c790726);
        IERC20(inputToken).transfer(sandwich, uint256(amountIn));

        (bytes memory payload, uint256 encodedValue) = mevHelper
            .v3CreateSandwichPayloadWethIsOutput(
                pool,
                inputToken,
                outputToken,
                fee,
                amountIn
            );
        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload);
        emit log_bytes(payload);

        changePrank(searcher, searcher);
        (bool s, ) = address(sandwich).call{value: encodedValue}(payload);
        assertTrue(s, "calling swap failed");
    }

    function testV3Weth1OutputBig1() public {
        address pool = 0x62CBac19051b130746Ec4CF96113aF5618F3A212;
        (address token0, address token1, uint24 fee) = GeneralHelper
            .getV3PoolInfo(pool);
        (address inputToken, address outputToken) = (token0, token1);

        int256 amountIn = 2.450740729522938570 ether;

        // fund sandwich contract
        vm.startPrank(0xeBc37F4c20C7F8336E81fB3aDf82f6372BEf777E);
        IERC20(inputToken).transfer(sandwich, uint256(amountIn));

        (bytes memory payload, uint256 encodedValue) = mevHelper
            .v3CreateSandwichPayloadWethIsOutput(
                pool,
                inputToken,
                outputToken,
                fee,
                amountIn
            );
        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload);
        emit log_bytes(payload);

        changePrank(searcher, searcher);
        (bool s, ) = address(sandwich).call{value: encodedValue}(payload);
        assertTrue(s, "calling swap failed");
    }

    function testV3Weth1OutputSmall() public {
        address pool = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
        (address token0, address token1, uint24 fee) = GeneralHelper
            .getV3PoolInfo(pool);
        (address inputToken, address outputToken) = (token0, token1);

        int256 amountIn = 1e10;
        // fund sandwich contract
        address binance14 = 0x28C6c06298d514Db089934071355E5743bf21d60;
        vm.startPrank(binance14);
        IERC20(inputToken).transfer(sandwich, uint256(amountIn));

        (bytes memory payload, uint256 encodedValue) = mevHelper
            .v3CreateSandwichPayloadWethIsOutput(
                pool,
                inputToken,
                outputToken,
                fee,
                amountIn
            );
        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload);

        changePrank(searcher, searcher);
        (bool s, ) = address(sandwich).call{value: encodedValue}(payload);
        assertTrue(s, "calling swap failed");
    }

    function testV3Weth1OutputBig() public {
        address pool = 0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8;
        (address token0, address token1, uint24 fee) = GeneralHelper
            .getV3PoolInfo(pool);
        (address inputToken, address outputToken) = (token0, token1);
        int256 amountIn = 1e21; // 1000 dai

        // fund sandwich contract
        vm.startPrank(0x25B313158Ce11080524DcA0fD01141EeD5f94b81);
        IERC20(inputToken).transfer(sandwich, uint256(amountIn));

        (bytes memory payload, uint256 encodedValue) = mevHelper
            .v3CreateSandwichPayloadWethIsOutput(
                pool,
                inputToken,
                outputToken,
                fee,
                amountIn
            );
        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload);

        changePrank(searcher, searcher);
        (bool s, ) = address(sandwich).call{value: encodedValue}(payload);
        assertTrue(s, "calling swap failed");
    }

    function testV3MultiMeatInput() public {
        V3Meat[2] memory meats = [
            V3Meat(
                0x7379e81228514a1D2a6Cf7559203998E20598346,
                address(0),
                1.2345678912341234 ether,
                true
            ),
            V3Meat(
                0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640,
                address(0),
                1.2345678912341234 ether,
                false
            )
        ];
        bytes memory payload;
        for (uint i = 0; i < meats.length; i++) {
            (address token0, address token1, uint24 fee) = GeneralHelper
                .getV3PoolInfo(meats[i].pool);
            (address inputToken, address outputToken) = token0 == address(weth)
                ? (token0, token1)
                : (token1, token0);
            (bytes memory subPayload, ) = mevHelper
                .v3CreateSandwichMultiMeatPayloadWethIsInput(
                    meats[i].pool,
                    inputToken,
                    outputToken,
                    fee,
                    meats[i].amountIn,
                    meats[i].isFirstOfPayload
                );
            payload = abi.encodePacked(payload, subPayload);
        }
        uint8 end = 0x2e;
        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload, end);
        emit log_bytes(payload);
        vm.prank(searcher, searcher);
        (bool s, ) = address(sandwich).call(payload);
        assertTrue(s, "calling v3 weth input multimeat swap failed");
    }

    function testV3MultiMeatOutput() public {
        V3Meat[4] memory meats = [
            V3Meat(
                0x7379e81228514a1D2a6Cf7559203998E20598346,
                0x56556075Ab3e2Bb83984E90C52850AFd38F20883,
                1e16,
                true
            ),
            V3Meat(
                0x64A078926AD9F9E88016c199017aea196e3899E1,
                0xD249942f6d417CbfdcB792B1229353B66c790726,
                100000 ether,
                false
            ),
            V3Meat(
                0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640,
                0x28C6c06298d514Db089934071355E5743bf21d60,
                1e10,
                false
            ),
            V3Meat(
                0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8,
                0x25B313158Ce11080524DcA0fD01141EeD5f94b81,
                1e21,
                false
            )
        ];
        bytes memory payload;
        for (uint i = 0; i < meats.length; i++) {
            (address token0, address token1, uint24 fee) = GeneralHelper
                .getV3PoolInfo(meats[i].pool);
            (address inputToken, address outputToken) = token0 == address(weth)
                ? (token1, token0)
                : (token0, token1);
            vm.prank(meats[i].faucet);
            IERC20(inputToken).transfer(sandwich, uint256(meats[i].amountIn));

            (bytes memory subPayload, ) = mevHelper
                .v3CreateSandwichMultiMeatPayloadWethIsOutput(
                    meats[i].pool,
                    inputToken,
                    outputToken,
                    fee,
                    meats[i].amountIn,
                    meats[i].isFirstOfPayload
                );
            payload = abi.encodePacked(payload, subPayload);
        }
        uint8 end = 0x2e;
        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload, end);
        emit log_bytes(payload);
        vm.prank(searcher, searcher);
        (bool s, ) = address(sandwich).call(payload);
        assertTrue(s, "calling multimeat swap failed");
    }

    function testHybridMultiMeatInput() public {
        V2Meat[1] memory v2Meats1 = [
            V2Meat(
                0xdAC17F958D2ee523a2206206994597C13D831ec7,
                address(0),
                1.94212341234123424 ether,
                true,
                true
            )
        ];
        V3Meat[2] memory v3Meats = [
            V3Meat(
                0x7379e81228514a1D2a6Cf7559203998E20598346,
                address(0),
                1.2345678912341234 ether,
                false
            ),
            V3Meat(
                0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640,
                address(0),
                1.2345678912341234 ether,
                false
            )
        ];
        V2Meat[1] memory v2Meats2 = [
            V2Meat(
                0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                address(0),
                0.942 ether,
                false,
                false
            )
        ];
        bytes memory payload;
        uint256 callvalue;
        for (uint i = 0; i < v2Meats1.length; i++) {
            (bytes memory subPayload, uint encodedValue) = mevHelper
                .v2CreateSandwichMultiPayloadWethIsInput(
                    v2Meats1[i].intermediateToken,
                    v2Meats1[i].amountIn,
                    v2Meats1[i].isFirstOfPayload
                );
            callvalue += encodedValue;
            payload = abi.encodePacked(payload, subPayload);
        }
        for (uint i = 0; i < v3Meats.length; i++) {
            (address token0, address token1, uint24 fee) = GeneralHelper
                .getV3PoolInfo(v3Meats[i].pool);
            (address inputToken, address outputToken) = token0 == address(weth)
                ? (token0, token1)
                : (token1, token0);
            (bytes memory subPayload, ) = mevHelper
                .v3CreateSandwichMultiMeatPayloadWethIsInput(
                    v3Meats[i].pool,
                    inputToken,
                    outputToken,
                    fee,
                    v3Meats[i].amountIn,
                    v3Meats[i].isFirstOfPayload
                );
            payload = abi.encodePacked(payload, subPayload);
        }
        for (uint i = 0; i < v2Meats2.length; i++) {
            (bytes memory subPayload, uint encodedValue) = mevHelper
                .v2CreateSandwichMultiPayloadWethIsInput(
                    v2Meats2[i].intermediateToken,
                    v2Meats2[i].amountIn,
                    v2Meats2[i].isFirstOfPayload
                );
            callvalue += encodedValue;
            payload = abi.encodePacked(payload, subPayload);
        }
        uint8 end = 0x2e;
        uint8 head = uint8(block.number);
        payload = abi.encodePacked(head, payload, end);
        emit log_bytes(payload);
        vm.prank(searcher, searcher);
        (bool s, ) = address(sandwich).call{value: callvalue}(payload);
        assertTrue(s, "calling hybrid weth input multimeat swap failed");
    }

    function testHybridMultiMeatOutput() public {
        V2Meat[1] memory v2meats1 = [
            V2Meat(
                0xe53EC727dbDEB9E2d5456c3be40cFF031AB40A55,
                binance8,
                1000000 ether,
                true,
                true
            )
        ];
        V3Meat[1] memory v3meats = [
            V3Meat(
                0x7379e81228514a1D2a6Cf7559203998E20598346,
                0x56556075Ab3e2Bb83984E90C52850AFd38F20883,
                1e16,
                false
            )
        ];
        V2Meat[1] memory v2meats2 = [
            V2Meat(
                0x6B175474E89094C44Da98b954EedeAC495271d0F,
                0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503,
                4722.366481770134 ether,
                false,
                false
            )
        ];
        bytes memory payload;
        uint256 callvalue;
        for (uint i = 0; i < v2meats1.length; i++) {
            address inputToken = v2meats1[i].intermediateToken;
            vm.prank(v2meats1[i].faucet);
            IERC20(inputToken).transfer(
                sandwich,
                uint256(v2meats1[i].amountIn)
            );
            (bytes memory subPayload, uint encodedValue) = mevHelper
                .v2CreateSandwichMultiPayloadWethIsOutput(
                    v2meats1[i].intermediateToken,
                    v2meats1[i].amountIn,
                    v2meats1[i].isFirstOfPayload
                );
            callvalue += encodedValue;
            payload = abi.encodePacked(payload, subPayload);
        }

        for (uint i = 0; i < v3meats.length; i++) {
            (address token0, address token1, uint24 fee) = GeneralHelper
                .getV3PoolInfo(v3meats[i].pool);
            (address inputToken, address outputToken) = token0 == address(weth)
                ? (token1, token0)
                : (token0, token1);
            vm.prank(v3meats[i].faucet);
            IERC20(inputToken).transfer(sandwich, uint256(v3meats[i].amountIn));

            (bytes memory subPayload, ) = mevHelper
                .v3CreateSandwichMultiMeatPayloadWethIsOutput(
                    v3meats[i].pool,
                    inputToken,
                    outputToken,
                    fee,
                    v3meats[i].amountIn,
                    v3meats[i].isFirstOfPayload
                );
            payload = abi.encodePacked(payload, subPayload);
        }

        for (uint i = 0; i < v2meats2.length; i++) {
            address inputToken = v2meats2[i].intermediateToken;
            vm.prank(v2meats2[i].faucet);
            IERC20(inputToken).transfer(
                sandwich,
                uint256(v2meats2[i].amountIn)
            );
            (bytes memory subPayload, uint encodedValue) = mevHelper
                .v2CreateSandwichMultiPayloadWethIsOutput(
                    v2meats2[i].intermediateToken,
                    v2meats2[i].amountIn,
                    v2meats2[i].isFirstOfPayload
                );
            callvalue += encodedValue;
            payload = abi.encodePacked(payload, subPayload);
        }

        emit log_uint(callvalue);
        uint8 head = uint8(block.number);
        uint8 end = 0x2e;
        payload = abi.encodePacked(head, payload, end);
        emit log_bytes(payload);
        vm.prank(searcher, searcher);
        (bool s, ) = address(sandwich).call{value: callvalue}(payload);
        assertTrue(s, "calling hybrid weth output multimeat swap failed");
    }

    // function testCustomPayload() public {
    //     // vm.roll(18749420);
    //     bytes memory frontrun_data = new bytes(153);
    //     assembly {
    //         mstore(
    //             add(frontrun_data, 0x20),
    //             0x4a165d18b30ac9f5e8d6b21a4b783d95fecc8b3c09c600e760cd4f1e0afd65ec
    //         )
    //         mstore(
    //             add(frontrun_data, 0x40),
    //             0x6b286d353c42268738d66bbf56ba9de555a9611e00018bc1bf68ca8609526dff
    //         )
    //         mstore(
    //             add(frontrun_data, 0x60),
    //             0x646034248308fb2a62d663620227c83570e300d00bd272431be359d4b1c4b449
    //         )
    //         mstore(
    //             add(frontrun_data, 0x80),
    //             0x4b4e37a6409b854eae989b98aeef3fa4250a6c58f7de2e6ee64f3f303d963aa9
    //         )
    //         mstore(
    //             add(frontrun_data, 0xa0),
    //             0x8f53cff98bbf4d3e4058689ea359dd488d026100000b96262500000000000000
    //         )
    //     }
    //     emit log_bytes(frontrun_data);
    //     uint callvalue = 121512037;
    //     vm.startPrank(searcher, searcher);
    //     (bool s, ) = address(sandwich).call{value: callvalue}(frontrun_data);
    //     assertTrue(s, "calling custom frontrun data multimeat swap failed");

    //     vm.startPrank(
    //         0x275A8D31bc87D5664249Db312001310a058B800e,
    //         0x275A8D31bc87D5664249Db312001310a058B800e
    //     );
    //     address to = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD;
    //     bytes memory meat_data = abi.encodeWithSelector(
    //         bytes4(0x3593564c),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000000000000000060
    //         ),
    //         bytes32(
    //             0x00000000000000000000000000000000000000000000000000000000000000a0
    //         ),
    //         bytes32(
    //             0x00000000000000000000000000000000000000000000000000000000657d03bb
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000000000000000003
    //         ),
    //         bytes32(
    //             0x0b08000000000000000000000000000000000000000000000000000000000000
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000000000000000003
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000000000000000060
    //         ),
    //         bytes32(
    //             0x00000000000000000000000000000000000000000000000000000000000000c0
    //         ),
    //         bytes32(
    //             0x00000000000000000000000000000000000000000000000000000000000001e0
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000000000000000040
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000000000000000002
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000001bc16d674ec80000
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000000000000000100
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000000000000000001
    //         ),
    //         bytes32(
    //             0x00000000000000000000000000000000000000000000000017979cfe362a0000
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000004e766db1648b3
    //         ),
    //         bytes32(
    //             0x00000000000000000000000000000000000000000000000000000000000000a0
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000000000000000000
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000000000000000002
    //         ),
    //         bytes32(
    //             0x000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000590cc9232ebf68d81f6707a119898219342ecb9
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000000000000000100
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000000000000000001
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000429d069189e0000
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000000dfc868a4d812
    //         ),
    //         bytes32(
    //             0x00000000000000000000000000000000000000000000000000000000000000a0
    //         ),
    //         bytes32(
    //             0x0000000000000000000000000000000000000000000000000000000000000000
    //         ),
    //         bytes32(
    //             0x000000000000000000000000000000000000000000000000000000000000002b
    //         ),
    //         bytes32(
    //             0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc20027100590cc9232ebf68d81
    //         ),
    //         bytes32(
    //             0xf6707a119898219342ecb9000000000000000000000000000000000000000000
    //         )
    //     );
    //     (s, ) = to.call{value: 2 ether}(meat_data);
    //     assertTrue(s, "calling meat data multimeat swap failed");

    //     bytes memory backrun_data = new bytes(236);
    //     assembly {
    //         mstore(
    //             add(backrun_data, 0x20),
    //             0x54365d18b30ac9f5e8d6b21a4b783d95fecc8b3c09c68a7b7b9b2f7d0c63f661
    //         )
    //         mstore(
    //             add(backrun_data, 0x40),
    //             0x71721339705a6188a7d500e760cc61593e0afd65ec6b286d353c42268738d66b
    //         )
    //         mstore(
    //             add(backrun_data, 0x60),
    //             0xbf56ba9de50590cc9232ebf68d81f6707a119898219342ecb9617bd36001e2cf
    //         )
    //         mstore(
    //             add(backrun_data, 0x80),
    //             0xde006172ca8609526dff646034248308fb2a62d663620227c001d3f06ad0617b
    //         )
    //         mstore(
    //             add(backrun_data, 0xa0),
    //             0xd3611a0590cc9232ebf68d81f6707a119898219342ecb9e359d4b1c4b4494b4e
    //         )
    //         mstore(
    //             add(backrun_data, 0xc0),
    //             0x37a6409b854eae989b98aeef3fa4250a6c58f7de2e6ee6593f303d963aa98f53
    //         )
    //         mstore(
    //             add(backrun_data, 0xe0),
    //             0xcff98bbf4d3e4058689ea359ddf8cacf121348eaa339f9e622e73f40058970df
    //         )
    //         mstore(
    //             add(backrun_data, 0x100),
    //             0x83488d02600b846c000042250000000000000000000000000000000000000000
    //         )
    //     }
    //     emit log_bytes(backrun_data);
    //     vm.startPrank(searcher, searcher);
    //     callvalue = 30954483968;
    //     (s, ) = address(sandwich).call{value: callvalue}(backrun_data);
    //     assertTrue(s, "calling custom backrun data multimeat swap failed");
    //     vm.stopPrank();
    // }

    // Test by recovering the initial funded amount
    function testRecoverWeth() public {
        vm.startPrank(searcher, searcher);

        uint256 recoverAmount = 100 ether;
        uint256 searcherBalanceBefore = address(searcher).balance;
        uint256 sandwichBalanceBefore = weth.balanceOf(sandwich);
        uint256 sandwichEthBalance = address(sandwich).balance;

        string memory functionName = "recoverWeth";
        bytes memory payload = abi.encodePacked(
            uint8(block.number),
            mevHelper.getJumpLabelFromSig(functionName)
        );
        uint encodedValue = recoverAmount / mevHelper.wethEncodeMultiple();
        uint realAmount = (recoverAmount / mevHelper.wethEncodeMultiple()) *
            mevHelper.wethEncodeMultiple();
        uint256 expectedAmountOut = sandwichEthBalance + realAmount;
        emit log_bytes(payload);
        (bool s, ) = sandwich.call{value: encodedValue}(payload);
        assertTrue(s, "calling recoverWeth failed");

        uint256 sandwichBalanceAfter = weth.balanceOf(sandwich);
        uint256 searcherBalanceAfter = address(searcher).balance;

        // check balance change
        assertTrue(
            sandwichBalanceBefore == sandwichBalanceAfter + realAmount,
            "sandwich weth balance should be zero"
        );
        assertTrue(
            searcherBalanceAfter == searcherBalanceBefore + expectedAmountOut,
            "searcher should gain all weth from sandwich"
        );
    }

    function testDepositWeth() public {
        vm.startPrank(searcher);
        uint256 searcherBalanceBefore = address(searcher).balance;
        uint sandwichWethBalanceBefore = weth.balanceOf(sandwich);
        console.log(sandwichWethBalanceBefore);
        uint amountDeposit = 0.1 ether;
        string memory functionName = "depositWeth";
        emit log_bytes(
            abi.encodePacked(mevHelper.getJumpLabelFromSig(functionName))
        );
        bytes memory payload = abi.encodePacked(
            uint8(block.number),
            mevHelper.getJumpLabelFromSig(functionName)
        );
        (bool s, ) = sandwich.call{value: amountDeposit}(payload);
        vm.stopPrank();
        assertTrue(s, "calling depositWeth failed");
        uint256 searcherBalanceAfter = address(searcher).balance;
        uint sandwichWethBalanceAfter = weth.balanceOf(sandwich);
        console.log(sandwichWethBalanceAfter);
        assertEq(searcherBalanceBefore - searcherBalanceAfter, amountDeposit);
        assertEq(
            sandwichWethBalanceAfter - sandwichWethBalanceBefore,
            amountDeposit
        );
    }

    function testBreakUniswapV3Callback() public {
        vm.startPrank(address(0x69696969));

        bytes memory payload = abi.encodePacked(uint8(250)); // 0xfa = 250
        (bool s, ) = sandwich.call(payload);
        assertFalse(s, "only pools should be able to call callback");
    }

    function testUnauthorized() public {
        vm.startPrank(address(0xf337babe));
        vm.deal(address(0xf337babe), 200 ether);

        string memory functionName = "recoverEth";
        bytes memory payload = abi.encodePacked(
            uint8(block.number),
            mevHelper.getJumpLabelFromSig(functionName)
        );
        (bool s, ) = sandwich.call(payload);

        assertFalse(s, "unauthorized addresses should not call recover eth");

        functionName = "recoverWeth";
        payload = abi.encodePacked(
            uint8(block.number),
            mevHelper.getJumpLabelFromSig(functionName)
        );
        (s, ) = sandwich.call(payload);

        assertFalse(
            s,
            "unauthorized addresses should not be able to call recover weth"
        );

        functionName = "seppuku";
        payload = abi.encodePacked(
            uint8(block.number),
            mevHelper.getJumpLabelFromSig(functionName)
        );
        (s, ) = sandwich.call(payload);

        assertFalse(
            s,
            "unauthorized addresses should not be able to seppuku contract"
        );
        changePrank(searcher);
        (s, ) = sandwich.call(payload);
        assertTrue(s, "calling recoverEth from searcher failed");
    }

    function testV2Arbitrage() public {
        uint256 wethBalanceBefore = weth.balanceOf(sandwich);
        vm.startPrank(searcher, searcher);
        address intermediaryToken = 0x249e38Ea4102D0cf8264d3701f1a0E39C4f2DC3B;
        V2Path[2] memory path = [
            V2Path(address(weth), intermediaryToken, uniswapV2Factory),
            V2Path(intermediaryToken, address(weth), shibaV2Factory)
        ];
        uint amountIn = 0.292721430179610624 ether;
        uint encodedValue = amountIn / mevHelper.wethEncodeMultiple();
        uint actualAmountIn = encodedValue * mevHelper.wethEncodeMultiple();
        bytes memory payload = abi.encodePacked(
            mevHelper.getJumpLabelFromSig("prepare_stack"),
            mevHelper.getJumpLabelFromSig("arbitrage_weth_input"),
            uint40(encodedValue)
        );
        for (uint i = 0; i < path.length; i++) {
            bool isTail = i == path.length - 1;
            (bytes memory subPayload, uint encodedAmountOut) = mevHelper
                .v2CreateArbitragePayload(
                    path[i].inputToken,
                    path[i].outputToken,
                    path[i].factory,
                    isTail,
                    actualAmountIn
                );
            payload = abi.encodePacked(payload, subPayload);
            actualAmountIn = encodedAmountOut;
        }
        uint8 end = 0x2e;
        payload = abi.encodePacked(payload, end);
        emit log_bytes(payload);
        (bool s, ) = sandwich.call(payload);
        assertTrue(s, "calling arbitrage failed");
        uint256 wethBalanceAfter = weth.balanceOf(sandwich);
        emit log_uint(wethBalanceBefore);
        emit log_uint(wethBalanceAfter);
    }
}
