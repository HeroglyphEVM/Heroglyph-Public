// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IHeroglyphRelay } from "src/relay/IHeroglyphRelay.sol";

interface IHeroglyphsRelayExtension {
    struct BlockProducerInfo {
        string validatorName;
        uint32 validatorIndex;
    }

    event DedicatedMsgSenderUpdated(address indexed dedicatedMsgSender);
    event RelayerUpdated(address indexed relayer);

    function getBlockProducerInfo(uint256 _blockId) external view returns (BlockProducerInfo memory);

    function executeRelay(IHeroglyphRelay.GraffitiData[] calldata _graffities) external returns (uint256); /*totalOfExecutions_*/
}
