// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract HeroOFTXCallbacksOperator {
    function _onValidatorCrossChainFailed(address _to, uint256 _idOrAmount) internal virtual;
    function _onValidatorSameChain(address _to) internal virtual returns (uint256 totalMinted_);
    function _onValidatorCrossChain(address _to)
        internal
        virtual
        returns (uint256 tokenIdOrAmount_, uint256 totalMinted_, bool success_);
}
