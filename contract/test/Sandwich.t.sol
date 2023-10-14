// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "foundry-huff/HuffDeployer.sol";
import "./helpers/GeneralHelper.sol";
import "./helpers/SandwichHelper.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import "./interfaces/IERC20.sol";
import "v3-core/interfaces/IUniswapV3Pool.sol";

contract SandwichTest is Test {
    address binance8 = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    // serachers
    address constant searcher = 0xfD22Ef4073d379cCa47c3c15AdFb1d3363967257;

    address sandwich;
    SandwichHelper sandwichHelper;
    IWETH weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
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

    function setUp() public {
        sandwichHelper = new SandwichHelper();
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

        uint256 actualAmountIn = (amountIn /
            sandwichHelper.wethEncodeMultiple()) *
            sandwichHelper.wethEncodeMultiple();
        uint256 amountOutFromEncoded = GeneralHelper.getAmountOut(
            address(weth),
            outputToken,
            actualAmountIn
        );
        (, , uint256 expectedAmountOut) = sandwichHelper
            .encodeNumToByteAndOffsetV2(amountOutFromEncoded, 4, true, false);

        (bytes memory payloadV4, uint256 encodedValue) = sandwichHelper
            .v2CreateSandwichPayloadWethIsInput(outputToken, amountIn);
        emit log_bytes(payloadV4);
        emit log_uint(encodedValue);
        vm.startPrank(searcher);
        uint checkpointGasLeft = gasleft();
        (bool s, ) = address(sandwich).call{value: encodedValue}(payloadV4);
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

        uint256 actualAmountIn = (amountIn /
            sandwichHelper.wethEncodeMultiple()) *
            sandwichHelper.wethEncodeMultiple();
        uint256 amountOutFromEncoded = GeneralHelper.getAmountOut(
            address(weth),
            outputToken,
            actualAmountIn
        );
        (, , uint256 expectedAmountOut) = sandwichHelper
            .encodeNumToByteAndOffsetV2(amountOutFromEncoded, 4, true, false);

        (bytes memory payloadV4, uint256 encodedValue) = sandwichHelper
            .v2CreateSandwichPayloadWethIsInput(outputToken, amountIn);
        vm.startPrank(searcher);
        uint checkpointGasLeft = gasleft();
        (bool s, ) = address(sandwich).call{value: encodedValue}(payloadV4);
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

        (, , uint256 actualAmountIn) = sandwichHelper
            .encodeNumToByteAndOffsetV2(superFarmBalanceBefore, 4, false, true);
        uint256 amountOutFromEncoded = GeneralHelper.getAmountOut(
            inputToken,
            address(weth),
            actualAmountIn
        );
        uint256 expectedAmountOut = (amountOutFromEncoded /
            sandwichHelper.wethEncodeMultiple()) *
            sandwichHelper.wethEncodeMultiple();

        // Perform swap
        (bytes memory payloadV4, uint256 encodedValue) = sandwichHelper
            .v2CreateSandwichPayloadWethIsOutput(inputToken, amountIn);
        emit log_bytes(payloadV4);
        emit log_uint(encodedValue);
        vm.startPrank(searcher);
        uint checkpointGasLeft = gasleft();
        (bool s, ) = address(sandwich).call{value: encodedValue}(payloadV4);
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
        vm.prank(0x075e72a5eDf65F0A5f44699c7654C1a76941Ddc8);
        IERC20(inputToken).transfer(sandwich, amountIn);

        // Pre swap checks
        uint256 wethBalanceBefore = weth.balanceOf(sandwich);
        uint256 daiBalanceBefore = IERC20(inputToken).balanceOf(sandwich);

        (, , uint256 actualAmountIn) = sandwichHelper
            .encodeNumToByteAndOffsetV2(daiBalanceBefore, 4, false, false);
        uint256 amountOutFromEncoded = GeneralHelper.getAmountOut(
            inputToken,
            address(weth),
            actualAmountIn
        );
        uint256 expectedAmountOut = (amountOutFromEncoded /
            sandwichHelper.wethEncodeMultiple()) *
            sandwichHelper.wethEncodeMultiple();

        // Perform swap
        (bytes memory payload, uint256 encodedValue) = sandwichHelper
            .v2CreateSandwichPayloadWethIsOutput(inputToken, amountIn);
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
            // uint actualAmountIn = (meats[i].amountIn /
            //     sandwichHelper.wethEncodeMultiple()) *
            //     sandwichHelper.wethEncodeMultiple();
            // uint256 amountOutFromEncoded = GeneralHelper.getAmountOut(
            //     address(weth),
            //     meats[i].intermediateToken,
            //     actualAmountIn
            // );
            // (, , uint256 expectedAmountOut) = sandwichHelper
            //     .encodeNumToByteAndOffsetV2(
            //         amountOutFromEncoded,
            //         4,
            //         true,
            //         meats[i].isWethToken0
            //     );
            (bytes memory subPayload, uint encodedValue) = sandwichHelper
                .v2CreateSandwichMultiPayloadWethIsInput(
                    meats[i].intermediateToken,
                    meats[i].amountIn,
                    meats[i].isFirstOfPayload
                );
            callvalue += encodedValue;
            payload = abi.encodePacked(payload, subPayload);
        }
        uint8 endPayload = 37;
        payload = abi.encodePacked(payload, endPayload);
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

        (bytes memory payload, uint256 encodedValue) = sandwichHelper
            .v3CreateSandwichPayloadWethIsInput(
                pool,
                inputToken,
                outputToken,
                fee,
                amountIn
            );
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

        (bytes memory payload, uint256 encodedValue) = sandwichHelper
            .v3CreateSandwichPayloadWethIsInput(
                pool,
                inputToken,
                outputToken,
                fee,
                amountIn
            );

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

        (bytes memory payload, uint256 encodedValue) = sandwichHelper
            .v3CreateSandwichPayloadWethIsOutput(
                pool,
                inputToken,
                outputToken,
                fee,
                amountIn
            );
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

        (bytes memory payload, uint256 encodedValue) = sandwichHelper
            .v3CreateSandwichPayloadWethIsOutput(
                pool,
                inputToken,
                outputToken,
                fee,
                amountIn
            );
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

        (bytes memory payload, uint256 encodedValue) = sandwichHelper
            .v3CreateSandwichPayloadWethIsOutput(
                pool,
                inputToken,
                outputToken,
                fee,
                amountIn
            );

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

        (bytes memory payload, uint256 encodedValue) = sandwichHelper
            .v3CreateSandwichPayloadWethIsOutput(
                pool,
                inputToken,
                outputToken,
                fee,
                amountIn
            );

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
            (bytes memory subPayload, ) = sandwichHelper
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
        uint8 endPayload = 37;
        payload = abi.encodePacked(payload, endPayload);
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

            (bytes memory subPayload, ) = sandwichHelper
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
        uint8 endPayload = 37;
        payload = abi.encodePacked(payload, endPayload);
        emit log_bytes(payload);
        vm.prank(searcher, searcher);
        (bool s, ) = address(sandwich).call(payload);
        assertTrue(s, "calling multimeat swap failed");
    }

    // Test by recovering the initial funded amount
    function testRecoverWeth() public {
        vm.startPrank(searcher, searcher);

        uint256 recoverAmount = 100 ether;
        uint256 searcherBalanceBefore = address(searcher).balance;
        uint256 sandwichBalanceBefore = weth.balanceOf(sandwich);
        uint256 sandwichEthBalance = address(sandwich).balance;

        string memory functionName = "recoverWeth";
        bytes memory payload = abi.encodePacked(
            sandwichHelper.getJumpLabelFromSig(functionName)
        );
        uint encodedValue = recoverAmount / sandwichHelper.wethEncodeMultiple();
        uint realAmount = (recoverAmount /
            sandwichHelper.wethEncodeMultiple()) *
            sandwichHelper.wethEncodeMultiple();
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
            abi.encodePacked(sandwichHelper.getJumpLabelFromSig(functionName))
        );
        bytes memory payload = abi.encodePacked(
            sandwichHelper.getJumpLabelFromSig(functionName)
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
            sandwichHelper.getJumpLabelFromSig(functionName)
        );
        (bool s, ) = sandwich.call(payload);

        assertFalse(s, "unauthorized addresses should not call recover eth");

        functionName = "recoverWeth";
        payload = abi.encodePacked(
            sandwichHelper.getJumpLabelFromSig(functionName)
        );
        (s, ) = sandwich.call(payload);

        assertFalse(
            s,
            "unauthorized addresses should not be able to call recover weth"
        );

        functionName = "seppuku";
        payload = abi.encodePacked(
            sandwichHelper.getJumpLabelFromSig(functionName)
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
}
