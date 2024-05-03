// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IHeroglyphFactory } from "./IHeroglyphFactory.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { CREATE3 } from "solmate/src/utils/CREATE3.sol";

/**
 * @title HeroglyphFactory
 * @notice Create supported ERCXXX with TickerOperation logic
 */
contract HeroglyphFactory is IHeroglyphFactory, Ownable {
    mapping(address factored => bool exists) private createdContracts;
    mapping(string model => bytes) private models;

    constructor(address _owner) Ownable(_owner) { }

    function deploy(string calldata _name, bytes32 _salt, bytes memory _args)
        external
        payable
        override
        returns (address deployed)
    {
        bytes memory creationCode = models[_name];
        if (creationCode.length == 0) revert NameNotFound();

        deployed = CREATE3.deploy(
            keccak256(abi.encodePacked(msg.sender, _salt)), abi.encodePacked(creationCode, _args), msg.value
        );

        createdContracts[deployed] = true;
        return deployed;
    }

    function registerContractTemplate(string calldata _name, bytes calldata _creationCode)
        external
        override
        onlyOwner
    {
        if (models[_name].length != 0) revert NameAlreadyUsed();
        models[_name] = _creationCode;
    }

    function updateModel(string calldata _name, bytes calldata _creationCode) external override onlyOwner {
        if (models[_name].length == 0) revert NameNotFound();

        models[_name] = _creationCode;
    }

    function fromThisFactory(address _contract) external view override returns (bool) {
        return createdContracts[_contract];
    }

    function getDeployed(address _deployer, bytes32 _salt) external view override returns (address deployed) {
        return CREATE3.getDeployed(keccak256(abi.encodePacked(_deployer, _salt)));
    }

    function getModel(string calldata _name) external view override returns (bytes memory code) {
        return models[_name];
    }
}
