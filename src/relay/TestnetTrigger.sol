// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title TestnetTrigger
 * @notice Ignore this, we use this to test the protocol on testnet
 */
contract TestnetTrigger {
    event TestnetTriggerGraffiti(uint256 indexed blockNumber, uint256 indexed slotNumber, string graffiti);

    function triggerGraffiti(uint256 slotNumber, string calldata graffiti) external {
        emit TestnetTriggerGraffiti(block.number, slotNumber, graffiti);
    }

    function multiTriggers(uint256 repeat, uint256 slot, string calldata graffiti) external {
        for (uint256 i = 0; i < repeat; i++) {
            emit TestnetTriggerGraffiti(block.number + repeat, slot, graffiti);
        }
    }
}
