// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IHeroglyphRelay } from "./../../../relay/IHeroglyphRelay.sol";
import { ITickerOperator, IGasPool } from "./ITickerOperator.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

/**
 * @title TickerOperator
 * @notice Template of what a Ticker Contract should have to execute successfully. This can be implmented in your if
 * needed
 */
abstract contract TickerOperator is ITickerOperator, Ownable {
    using OptionsBuilder for bytes;

    IHeroglyphRelay public immutable heroglyphRelay;
    address public feePayer;

    modifier onlyRelay() {
        if (msg.sender != address(heroglyphRelay)) revert NotHeroglyph();
        _;
    }

    constructor(address _owner, address _heroglyphRelay, address _feePayer) Ownable(_owner) {
        if (_feePayer == address(0)) _feePayer = address(this);

        feePayer = _feePayer;
        heroglyphRelay = IHeroglyphRelay(_heroglyphRelay);
    }

    /**
     * @notice _repayHeroglyph repay the HeroglyphRelay contract for executing your code
     * @dev it should be call at the end / near the end of your code. It uses gasLeft() to calculate the
     * cost of the fee.
     */
    function _repayHeroglyph() internal virtual returns (uint256 feePaid_) {
        feePaid_ = heroglyphRelay.getExecutionNativeFee(10_000);
        if (feePaid_ == 0) return 0;

        if (_askFeePayerToPay(address(heroglyphRelay), feePaid_)) return feePaid_;

        (bool success,) = address(heroglyphRelay).call{ value: feePaid_ }("");
        if (!success) revert FailedToSendETH();

        return feePaid_;
    }

    function _askFeePayerToPay(address _to, uint256 _amount) internal returns (bool success_) {
        if (feePayer == address(this) || feePayer == address(0)) return false;

        IGasPool(feePayer).payTo(_to, _amount);
        return true;
    }

    /**
     * @notice updateFeePayer Update the fee payer
     * @param _feePayer address of the one paying the LZ fee or/and HeroglyphRelay fee (if any)
     */
    function updateFeePayer(address _feePayer) external virtual onlyOwner {
        feePayer = _feePayer;

        emit FeePayerUpdated(_feePayer);
    }
}
