// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../BaseScript.sol";
import { ValidatorIdentityV2 } from "src/identity/wallet/v2/ValidatorIdentityV2.sol";
import { HeroglyphRelay } from "src/relay/HeroglyphRelay.sol";
import { HeroglyphAttestation } from "src/HeroglyphAttestation.sol";
import { Ticker } from "src/identity/ticker/Ticker.sol";
import { NameFilter } from "src/identity/NameFilter.sol";
import { IdentityERC721 } from "src/identity/IdentityERC721.sol";

import { IdentityRouter } from "src/identity/wallet/IdentityRouter.sol";
import { DeployUtils } from "../utils/DeployUtils.sol";

contract DeployProtocolScript is BaseScript, DeployUtils {
    string private constant CONFIG_NAME = "ProtocolConfig";

    Config config;
    uint256 activeDeployer;
    address deployerWallet;

    function run(string memory _network) external {
        _setNetwork(_network);

        activeDeployer = _getDeployerPrivateKey();
        deployerWallet = _getDeployerAddress();

        string memory file = _getConfig(CONFIG_NAME);
        config = abi.decode(vm.parseJson(file, string.concat(".", _getNetwork())), (Config));

        _loadContracts();

        (address nameFilter,) = _tryDeployContract(CONTRACT_NAME_NAME_FILTER, 0, type(NameFilter).creationCode, "");

        (address validatorIdentity,) = _tryDeployContract(
            CONTRACT_NAME_VALIDATOR_IDENTITY_V2,
            0,
            type(ValidatorIdentityV2).creationCode,
            abi.encode(
                config.owner,
                config.treasury,
                nameFilter,
                config.validatorIdentityCost,
                contracts[CONTRACT_NAME_VALIDATOR_IDENTITY]
            )
        );

        if (_isSimulation()) {
            _verifyIdentityDeployment(IdentityERC721(validatorIdentity), nameFilter);
        }

        (address ticker,) = _tryDeployContract(
            CONTRACT_NAME_TICKER,
            0,
            type(Ticker).creationCode,
            abi.encode(config.owner, config.treasury, nameFilter, config.tickerCost)
        );

        if (_isSimulation()) {
            _verifyIdentityDeployment(IdentityERC721(ticker), nameFilter);
        }

        (address identityRouter,) = _tryDeployContract(
            CONTRACT_NAME_IDENTITY_ROUTER,
            0,
            type(IdentityRouter).creationCode,
            abi.encode(config.owner, validatorIdentity)
        );

        if (_isSimulation()) {
            assert(IdentityRouter(identityRouter).owner() == config.owner);
            assert(address(IdentityRouter(identityRouter).validatorIdentity()) == validatorIdentity);
        }

        (address heroglyphRelay,) = _tryDeployContract(
            CONTRACT_NAME_HEROGLYPH_RELAY,
            0,
            type(HeroglyphRelay).creationCode,
            abi.encode(config.owner, identityRouter, config.dedicatedMsgSender, ticker, config.treasury)
        );

        if (_isSimulation()) {
            _verifyHeroglyphRelay(HeroglyphRelay(payable(heroglyphRelay)), identityRouter, ticker);
        }

        (address heroglyphAttestation,) = _tryDeployContract(
            CONTRACT_NAME_HEROGLYPH_ATTESTATION,
            0,
            type(HeroglyphAttestation).creationCode,
            abi.encode(config.dedicatedMsgSender, validatorIdentity, config.owner)
        );

        if (_isSimulation()) {
            _verifyHeroglyphAttestation(HeroglyphAttestation(heroglyphAttestation), validatorIdentity);
        }
    }

    function _verifyIdentityDeployment(IdentityERC721 _contract, address _nameFilter) private view {
        assert(_contract.treasury() == config.treasury);
        assert(address(_contract.nameFilter()) == _nameFilter);
        assert(_contract.cost() == config.validatorIdentityCost);
        assert(_contract.owner() == config.owner);
    }

    function _verifyHeroglyphRelay(HeroglyphRelay _contract, address _identityRouter, address _ticker) private view {
        assert(_contract.owner() == config.owner);
        assert(address(_contract.identityRouter()) == _identityRouter);
        assert(address(_contract.tickers()) == _ticker);
        assert(_contract.treasury() == config.treasury);
        assert(_contract.dedicatedMsgSender() == config.dedicatedMsgSender);
    }

    function _verifyHeroglyphAttestation(HeroglyphAttestation _contract, address _identity) private view {
        assert(_contract.owner() == config.owner);
        assert(_contract.dedicatedMsgSender() == config.dedicatedMsgSender);
        assert(address(_contract.validatorIdentity()) == _identity);
    }
}
