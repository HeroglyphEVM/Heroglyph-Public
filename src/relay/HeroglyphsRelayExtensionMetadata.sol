// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IHeroglyphRelay } from "src/relay/IHeroglyphRelay.sol";
import { IHeroglyphsRelayExtension } from "src/relay/IHeroglyphsRelayExtension.sol";

contract HeroglyphsRelayExtensionMetadata is IHeroglyphsRelayExtension, Ownable {
    address public dedicatedMsgSender;
    IHeroglyphRelay public relayer;

    mapping(uint256 blockId => BlockProducerInfo) private blockProducerInfo;

    constructor(address _owner, address _dedicatedMsgSender, address _relayer) Ownable(_owner) {
        dedicatedMsgSender = _dedicatedMsgSender;
        relayer = IHeroglyphRelay(_relayer);
    }

    function executeRelay(IHeroglyphRelay.GraffitiData[] calldata _graffities)
        external
        override
        returns (uint256 /*totalOfExecutions_*/ )
    {
        require(msg.sender == dedicatedMsgSender, "Not dedicated msg sender");

        for (uint256 i = 0; i < _graffities.length; ++i) {
            blockProducerInfo[_graffities[i].mintedBlock] = BlockProducerInfo({
                validatorName: _graffities[i].validatorName,
                validatorIndex: _graffities[i].validatorIndex
            });
        }

        return relayer.executeRelay(_graffities);
    }

    function updateDedicatedMsgSender(address _dedicatedMsgSender) external onlyOwner {
        dedicatedMsgSender = _dedicatedMsgSender;
        emit DedicatedMsgSenderUpdated(_dedicatedMsgSender);
    }

    function updateRelayer(address _relayer) external onlyOwner {
        relayer = IHeroglyphRelay(_relayer);
        emit RelayerUpdated(_relayer);
    }

    function getBlockProducerInfo(uint256 _blockId) external view override returns (BlockProducerInfo memory) {
        return blockProducerInfo[_blockId];
    }
}
