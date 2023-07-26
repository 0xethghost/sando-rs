// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "foundry-huff/HuffDeployer.sol";
import "../interfaces/IMetamorphicContractFactory.sol";

contract Deploy is Script {
    IMetamorphicContractFactory factory;
    // serachers
    function setUp() public {
      factory = IMetamorphicContractFactory(0x00000000e82eb0431756271F0d00CFB143685e7B);
    }

    function run() public{
        address sandwich = HuffDeployer.broadcast("sandwich");
        bytes32 salt = bytes32(0x501e809c8c8d268e136b6975b331ea398e07d35ebb0885e23d242006e3a20d87);
        vm.broadcast(0x501E809C8C8d268E136B6975b331EA398e07d35e);
        address metamorphicContract = factory.deployMetamorphicContractFromExistingImplementation(salt, sandwich, "");
        console.log(metamorphicContract);
    }
}