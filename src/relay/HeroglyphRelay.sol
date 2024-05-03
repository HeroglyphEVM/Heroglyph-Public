// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IHeroglyphRelay } from "./IHeroglyphRelay.sol";
import { HeroglyphAttestation } from "./../HeroglyphAttestation.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SendNativeHelper } from "./../SendNativeHelper.sol";

import { ITickerOperator } from "./../identity/ticker/operator/ITickerOperator.sol";
import { ITicker } from "./../identity/ticker/ITicker.sol";
import { IValidatorIdentity } from "./../identity/wallet/IValidatorIdentity.sol";

/**
 * @title HeroglyphRelay
 * @notice The bridge between off-chain and on-chain execution. It receives graffiti metadata and executes based on its
 * parameters.
 * Since the graffiti originates from the block producer, we reward attestors of this block by
 * giving them "HeroglyphAttestation" tokens. Note: The miner won't receive any `HeroglyphAttestation` token.
 *
 * "HeroglyphAttestation" tokens can be redeemed for one of our own tokens that will be available at launch.
 * Other projects might have a redemption mechanism in place too.
 *
 * A "Ticker" can revert if it:
 * 1. Exceeds the gas limit,
 * 2. Fails to pay the fee, or
 * 3. Is invalid (empty address or not inheriting the ITickerOperation.sol interface),
 * we revert and continue to the next one in the list. Tickers are optional.
 *
 * See IHeroglyphRelay for function docs
 */
contract HeroglyphRelay is IHeroglyphRelay, Ownable, SendNativeHelper {
    IValidatorIdentity public immutable validatorIdentity;
    ITicker public immutable tickers;
    address public dedicatedMsgSender;
    address public treasury;

    uint128 public nativeFeePerUnit;
    uint128 private startGas;
    uint32 public lastBlockMinted;

    uint32 public gasLimitPerTicker;
    uint32 private startGasTicker;
    uint128 public gasRatioPerUnit;
    uint128 public extraGasCredit;

    modifier onlyDedicatedMsgSender() {
        if (msg.sender != dedicatedMsgSender) revert NotDedicatedMsgSender();

        _;
    }

    constructor(
        address _owner,
        address _validatorIdentity,
        address _dedicatedMsgSender,
        address _tinkers,
        address _treasury
    ) Ownable(_owner) {
        dedicatedMsgSender = _dedicatedMsgSender;
        validatorIdentity = IValidatorIdentity(_validatorIdentity);
        tickers = ITicker(_tinkers);
        treasury = _treasury;

        nativeFeePerUnit = 0;
        gasLimitPerTicker = 400_000;
        gasRatioPerUnit = 20_000;
        extraGasCredit = 36_000;
    }

    function executeRelay(GraffitiData[] calldata _graffities)
        external
        override
        onlyDedicatedMsgSender
        returns (uint256 totaltOfExecutions_)
    {
        if (_graffities.length == 0) revert EmptyGraffities();

        GraffitiData memory _graffiti;
        ITicker.TickerMetadata memory tickerData;
        uint32 mintedBlock;
        address validator;
        string[] memory tickerNames;
        uint32[] memory lzEndpoints;
        uint32 arraysLength;
        uint32 cachedGasLimit = gasLimitPerTicker;
        string memory tickerName;
        address tickerTarget;
        uint32 lzEndpointId;
        bool shouldBeSurrender;
        for (uint256 i = 0; i < _graffities.length; ++i) {
            _graffiti = _graffities[i];
            mintedBlock = _graffiti.mintedBlock;

            if (mintedBlock <= lastBlockMinted) continue;
            lastBlockMinted = mintedBlock;

            validator = validatorIdentity.getIdentityData(0, _graffiti.validatorName).tokenReceiver;
            if (validator == address(0)) continue;

            tickerNames = _graffiti.tickers;
            lzEndpoints = _graffiti.lzEndpointTargets;
            arraysLength = uint32(lzEndpoints.length);

            if (tickerNames.length != arraysLength) continue;

            for (uint16 x = 0; x < arraysLength; ++x) {
                tickerName = tickerNames[x];
                lzEndpointId = lzEndpoints[x];

                (tickerData, shouldBeSurrender) = tickers.getTickerMetadata(0, tickerName);

                tickerTarget = tickerData.contractTarget;

                if (tickerTarget == address(0) || shouldBeSurrender || tickerData.price == 0) continue;

                try this.callTicker(tickerTarget, cachedGasLimit, lzEndpointId, mintedBlock, validator) {
                    emit TickerExecuted(tickerName, validator, mintedBlock, tickerTarget, lzEndpointId);
                } catch (bytes memory errorCode) {
                    emit TickerReverted(tickerName, tickerTarget, errorCode);
                    continue;
                }
            }

            totaltOfExecutions_++;
            emit BlockExecuted(mintedBlock, _graffiti.slotNumber, validator, _graffiti.graffitiText);
        }

        if (totaltOfExecutions_ == 0) revert NoGraffitiExecution();

        _sendNative(treasury, address(this).balance, false);

        return totaltOfExecutions_;
    }

    function callTicker(
        address _ticker,
        uint32 _gasLimit,
        uint32 _lzEndpointSelectionned,
        uint32 _blockNumber,
        address _validatorWithdrawer
    ) external {
        if (msg.sender != address(this)) revert NoPermission();
        if (_ticker == address(0)) revert NullAddress();

        uint128 balanceBefore = uint128(address(this).balance);
        uint128 maxFee = _getExecutionNativeFee(_gasLimit, 0);

        startGasTicker = _gasLimit;

        //compensate for onValidatorTriggered && getExecutionNativeFee call
        startGas = uint128(gasleft() - extraGasCredit);

        ITickerOperator(_ticker).onValidatorTriggered{ gas: _gasLimit }(
            _lzEndpointSelectionned, _blockNumber, _validatorWithdrawer, maxFee
        );

        uint128 due = _getExecutionNativeFee(startGas, uint128(gasleft()));
        uint128 balanceNow = uint128(address(this).balance) - balanceBefore;

        if (balanceNow < due) revert NotRefunded();
    }

    function getExecutionNativeFee(uint128 _addExtra) external view override returns (uint128) {
        return _getExecutionNativeFee(_addExtra + startGasTicker, uint128(gasleft()));
    }

    function _getExecutionNativeFee(uint128 _start, uint128 _end) internal view returns (uint128) {
        if (_start <= _end) return 0;
        return (((_start - _end) / gasRatioPerUnit) * nativeFeePerUnit);
    }

    function withdrawETH(address _to) external onlyOwner {
        _sendNative(_to, address(this).balance, true);
    }

    function updateCostPerUnit(uint128 _costPerUnit) external onlyOwner {
        nativeFeePerUnit = _costPerUnit;
        emit CostPerUnitUpdated(_costPerUnit);
    }

    function updateGasRatioPerUnit(uint128 _gasRatioPerUnit) external onlyOwner {
        if (_gasRatioPerUnit == 0) revert CannotBeZero();
        gasRatioPerUnit = _gasRatioPerUnit;
        emit GasPerUnitUpdated(gasRatioPerUnit);
    }

    function updateExtraGasCredit(uint128 _gasCredit) external onlyOwner {
        extraGasCredit = _gasCredit;
        emit ExtraGasCreditUpdate(_gasCredit);
    }

    function updateGasLimitPerTicker(uint32 _gasLimit) external onlyOwner {
        if (_gasLimit < 50_000) revert GasLimitTooLow();

        gasLimitPerTicker = _gasLimit;
        emit GasLimitUpdated(_gasLimit);
    }

    function updateDedicatedMsgSender(address _msg) external onlyOwner {
        dedicatedMsgSender = _msg;
        emit DedicatedMsgSenderUpdated(_msg);
    }

    function updateTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert MissingTreasury();

        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    receive() external payable { }
}
