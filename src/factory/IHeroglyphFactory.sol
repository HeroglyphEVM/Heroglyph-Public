// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

interface IHeroglyphFactory {
    error NameAlreadyUsed();
    error NameNotFound();

    function deploy(string calldata _name, bytes32 _salt, bytes memory _args)
        external
        payable
        returns (address deployed);
    function registerContractTemplate(string calldata _name, bytes calldata _creationCode) external;
    function updateModel(string calldata _name, bytes calldata _creationCode) external;
    function fromThisFactory(address _contract) external view returns (bool);
    function getDeployed(address _deployer, bytes32 _salt) external view returns (address deployed);
    function getModel(string calldata _name) external view returns (bytes memory code);
}
