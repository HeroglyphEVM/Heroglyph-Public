// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { HeroOFTXOperator } from "../extension/HeroOFTXOperator.sol";
import { BaseOFT20, ERC20 } from "./BaseOFT20.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title OFT20Ticker
 * @notice ERC20 + LZv2 + TickerOperator
 * @dev You will need to implements the following functions
 * - _onValidatorSameChain(address _to)
 * - _onValidatorCrossChain(address _to)
 */
abstract contract OFT20Ticker is BaseOFT20, HeroOFTXOperator {
    error FeeTooHigh();

    uint32 public crossChainFee;
    address public feeCollector;

    constructor(
        string memory _name,
        string memory _symbol,
        address _feeCollector,
        uint32 _crossChainFee,
        HeroOFTXOperatorArgs memory _heroArgs
    ) ERC20(_name, _symbol) HeroOFTXOperator(_heroArgs) BaseOFT20(18) {
        crossChainFee = _crossChainFee;
        feeCollector = _feeCollector;
    }

    function _onValidatorCrossChainFailed(address _to, uint256 _amount) internal override {
        _mint(_to, _amount);
    }

    function _toLocalDecimals(uint64 _value) internal view override returns (uint256) {
        return _toLD(_value);
    }

    function _toSharedDecimals(uint256 _value) internal view override returns (uint64) {
        return _toSD(_value);
    }

    function _credit(address _to, uint256 _value, bool _isFrozen) internal override returns (uint256) {
        if (_isFrozen) return _value;

        _mint(_to, _value);

        return _value;
    }

    function _debit(uint256 _amountIn, uint256 _minAmountOut)
        internal
        virtual
        override
        returns (uint256 amountReceiving_)
    {
        (uint256 amountSentLD, uint256 amountReceivedLD) = _debitView(_amountIn, _minAmountOut);

        if (amountReceivedLD < amountSentLD) {
            _mint(feeCollector, amountSentLD - amountReceivedLD);
        }

        _burn(msg.sender, amountSentLD);

        return amountReceivedLD;
    }

    function _debitView(uint256 _amountLD, uint256 _minAmountLD)
        internal
        view
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        amountSentLD = _removeDust(_amountLD);
        amountReceivedLD = amountSentLD - Math.mulDiv(amountSentLD, crossChainFee, 10_000);

        if (amountReceivedLD < _minAmountLD) {
            revert SlippageExceeded(amountReceivedLD, _minAmountLD);
        }

        return (amountSentLD, amountReceivedLD);
    }

    function updateCrossChainFee(uint32 _fee) external onlyOwner {
        if (_fee > 1000) revert FeeTooHigh();
        crossChainFee = _fee;
    }

    function updateFeeCollector(address _feeCollector) external onlyOwner {
        feeCollector = _feeCollector;
    }
}
