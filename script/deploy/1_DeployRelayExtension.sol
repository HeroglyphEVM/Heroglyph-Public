// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../BaseScript.sol";
import { HeroglyphsRelayExtensionMetadata } from "src/relay/HeroglyphsRelayExtensionMetadata.sol";

contract DeployRelayExtensionScript is BaseScript {
    string private constant CONFIG_NAME = "RelayExtensionConfig";

    struct RelayConfig {
        address owner;
        address relayer;
        address dedicatedMsgSender;
    }

    RelayConfig config;
    uint256 activeDeployer;
    address deployerWallet;

    function run(string memory _network) external {
        _setNetwork(_network);

        activeDeployer = _getDeployerPrivateKey();
        deployerWallet = _getDeployerAddress();

        string memory file = _getConfig(CONFIG_NAME);
        config = abi.decode(vm.parseJson(file, string.concat(".", _getNetwork())), (RelayConfig));

        _loadContracts();

        _tryDeployContract(
            "HeroglyphsRelayExtensionMetadata",
            0,
            type(HeroglyphsRelayExtensionMetadata).creationCode,
            abi.encode(config.owner, config.dedicatedMsgSender, config.relayer)
        );
    }
}
