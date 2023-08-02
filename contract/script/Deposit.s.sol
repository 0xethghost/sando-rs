// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "./helpers/SandwichHelper.sol";

contract Deposit is Script {
    address sandwich;
    SandwichHelper sandwichHelper;
    // serachers
    function setUp() public {
        sandwich = 0x000000146741612bA673d5c70000c65e6bf9e100;
        sandwichHelper = new SandwichHelper();
    }

    function run() public{
        uint8 depositLabel = sandwichHelper.getJumpLabelFromSig("depositWeth");
        bytes memory payload = abi.encodePacked(depositLabel);
        uint amountDeposit = 0.1 ether;
        uint256 searcherPrivateKey = vm.envUint("SEARCHER_PRIVATE_KEY");
        vm.broadcast(searcherPrivateKey);
        // vm.broadcast(0x501E809C8C8d268E136B6975b331EA398e07d35e);
        (bool s, ) = sandwich.call{value: amountDeposit}(payload);
    }
}