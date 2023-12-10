// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";

contract Seppuku is Script {
    address sandwich;
    mapping(string => uint8) internal functionSigsToJumpLabel;
    // serachers
    function setUp() public {
        setupSigJumpLabelMapping();
        sandwich = 0x000000146741612bA673d5c70000c65e6bf9e100;
    }

    function run() public{
        uint8 seppukuLabel = getJumpLabelFromSig("seppuku");
        bytes memory payload = abi.encodePacked(seppukuLabel);
        uint256 searcherPrivateKey = vm.envUint("SEARCHER_PRIVATE_KEY");
        vm.broadcast(searcherPrivateKey);
        (bool result,) = sandwich.call(payload);
        require(result, "Call reverted");
    }

    
    function getJumpLabelFromSig(
        string memory sig
    ) public view returns (uint8) {
        return functionSigsToJumpLabel[sig];
    }

    function setupSigJumpLabelMapping() private {
        uint256 startingIndex = 0x27;

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