// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";

contract Withdraw is Script {
    address sandwich;
    mapping(string => uint8) internal functionSigsToJumpLabel;

    // serachers
    function setUp() public {
        setupSigJumpLabelMapping();
        sandwich = 0x000000146741612bA673d5c70000c65e6bf9e100;
    }

    function run() public {
        uint8 withdrawLabel = getJumpLabelFromSig("recoverWeth");
        uint amountWithdraw = 0.35 ether;
        bytes memory payload = abi.encodePacked(withdrawLabel, amountWithdraw);
        console.logBytes(payload);
        uint256 searcherPrivateKey = vm.envUint("SEARCHER_PRIVATE_KEY");
        vm.broadcast(searcherPrivateKey);
        (bool result, ) = sandwich.call(payload);
        require(result, "Call reverted");
    }

    function getJumpLabelFromSig(
        string memory sig
    ) public view returns (uint8) {
        return functionSigsToJumpLabel[sig];
    }

    function setupSigJumpLabelMapping() private {
        uint256 startingIndex = 0x27;

        string[14] memory functionNames = [
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
