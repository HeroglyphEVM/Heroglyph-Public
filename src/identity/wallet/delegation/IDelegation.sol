// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IDelegation {
    function isDelegated(string calldata _idName, uint32 _validatorId) external view returns (bool);

    function snapshot(string calldata _idName, uint32 _validatorId, address _tickerContract) external;
}
