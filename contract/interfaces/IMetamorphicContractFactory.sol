// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IMetamorphicContractFactory {
    function deployMetamorphicContractFromExistingImplementation(
    bytes32 salt,
    address implementationContract,
    bytes calldata metamorphicContractInitializationCalldata
  ) external returns (
    address metamorphicContractAddress
  );
}
