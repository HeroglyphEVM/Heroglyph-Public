// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title SendNativeHelper
 * @notice This helper facilitates the sending of native tokens and manages actions in case of reversion or tracking
 * rewards upon failure.
 */
abstract contract SendNativeHelper {
    error NotEnough();
    error FailedToSendETH();

    mapping(address wallet => uint256) internal pendingClaims;

    function _sendNative(address _to, uint256 _amount, bool _revertIfFails) internal {
        if (_amount == 0) return;

        (bool success,) = _to.call{ gas: 60_000, value: _amount }("");

        if (!success) {
            if (_revertIfFails) revert FailedToSendETH();
            pendingClaims[_to] += _amount;
        }
    }

    function claimFund() external {
        uint256 balance = pendingClaims[msg.sender];
        pendingClaims[msg.sender] = 0;

        if (balance == 0) revert NotEnough();

        _sendNative(msg.sender, balance, true);
    }

    function getPendingToClaim(address _user) external view returns (uint256) {
        return pendingClaims[_user];
    }
}
