// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract DeployUtils {
    string internal constant CONTRACT_NAME_HEROGLYPH_ATTESTATION = "HeroglyphAttestation";
    string internal constant CONTRACT_NAME_HEROGLYPH_RELAY = "HeroglyphRelay";
    string internal constant CONTRACT_NAME_VALIDATOR_IDENTITY = "ValidatorIdentity";
    string internal constant CONTRACT_NAME_VALIDATOR_IDENTITY_V2 = "ValidatorIdentityV2";
    string internal constant CONTRACT_NAME_TICKER = "Ticker";
    string internal constant CONTRACT_NAME_NAME_FILTER = "NameFilterV1";
    string internal constant CONTRACT_NAME_TESTNET_TRIGGER = "TestnetTrigger";
    string internal constant CONTRACT_NAME_IDENTITY_ROUTER = "IdentityRouter";
    uint88 internal constant PROTOCOL_OFFSET = 0;
    uint88 internal constant TOKENS_OFFSET = 1000;
    uint88 internal constant KEYS_OFFSET = 2000;
    uint88 internal constant MILADY_OFFSET = 3000;
    uint88 internal constant REDEPLOY_OFFSET = 30_000;

    struct Config {
        address owner;
        address treasury;
        address lzEndpoint;
        address dedicatedMsgSender;
        uint32 lzDeploymentChainEndpointId;
        uint256 validatorIdentityCost;
        uint256 tickerCost;
        // Native Token Wrapped -> Native == where the protocol is hosted, this is to repay the fees
        address nativeTokenWrapped;
        address create3Factory;
        bool isTestnet;
    }
}
