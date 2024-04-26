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
        bytes32 salt = bytes32(0x91bf9f374fd56cc3c421f9c988af6e5c4a61df8262bc4795a02024e288e38303);
        vm.broadcast(0x91BF9F374fD56CC3C421f9C988af6E5C4A61DF82);
        address metamorphicContract = factory.deployMetamorphicContractFromExistingImplementation(salt, sandwich, "");
        console.log(metamorphicContract);
    }
}