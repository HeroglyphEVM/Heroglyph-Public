// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract HeroOFTXCallbacks {
    function _debit(uint256 _amountOrId, uint256 _minAmount) internal virtual returns (uint256 _amountSendingOrId_);
    function _credit(address _to, uint256 _value, bool _isFrozen) internal virtual returns (uint256 amountReceived_);
}
