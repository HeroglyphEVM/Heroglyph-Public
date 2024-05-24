// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IHeroglyphRelay } from "./IHeroglyphRelay.sol";
import { HeroglyphAttestation } from "./../HeroglyphAttestation.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SendNativeHelper } from "./../SendNativeHelper.sol";

import { ITickerOperator } from "heroglyph-library/src/ITickerOperator.sol";
import { ITicker } from "./../identity/ticker/ITicker.sol";
import { IdentityRouter } from "./../identity/wallet/IdentityRouter.sol";
import { IDelegation } from "./../identity/wallet/delegation/IDelegation.sol";

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
    uint32 public constant GAS_LIMIT_MINIMUM = 50_000;

    IdentityRouter public identityRouter;
    ITicker public tickers;
    address public dedicatedMsgSender;
    address public treasury;

    uint32 public lastBlockMinted;
    uint32 public gasLimitPerTicker;
    uint128 public executionFee;

    modifier onlyDedicatedMsgSender() {
        if (msg.sender != dedicatedMsgSender) revert NotDedicatedMsgSender();

        _;
    }

    constructor(
        address _owner,
        address _identityRouter,
        address _dedicatedMsgSender,
        address _tickers,
        address _treasury
    ) Ownable(_owner) {
        dedicatedMsgSender = _dedicatedMsgSender;
        identityRouter = IdentityRouter(_identityRouter);
        tickers = ITicker(_tickers);
        treasury = _treasury;

        gasLimitPerTicker = 400_000;
    }

    function executeRelay(GraffitiData[] calldata _graffities)
        external
        override
        onlyDedicatedMsgSender
        returns (uint256 totalOfExecutions_)
    {
        if (_graffities.length == 0) revert EmptyGraffities();

        uint32 cachedGasLimit = gasLimitPerTicker;
        uint32 lastBlockMintedCached = lastBlockMinted;
        uint128 cachedExecutionFee = executionFee;

        GraffitiData memory _graffiti;
        ITicker.TickerMetadata memory tickerData;
        uint32 mintedBlock;
        address validator;
        string[] memory tickerNames;
        uint32[] memory lzEndpoints;
        uint32 arraysLength;
        string memory tickerName;
        address tickerTarget;
        uint32 lzEndpointId;
        bool shouldBeSurrender;
        string memory validatorName;
        bool isDelegation;

        for (uint256 i = 0; i < _graffities.length; ++i) {
            _graffiti = _graffities[i];
            mintedBlock = _graffiti.mintedBlock;
            validatorName = _graffiti.validatorName;

            if (mintedBlock <= lastBlockMintedCached) continue;
            lastBlockMintedCached = mintedBlock;

            (validator, isDelegation) = identityRouter.getWalletReceiver(validatorName, _graffiti.validatorIndex);
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

                try this.callTicker(
                    tickerTarget, cachedGasLimit, cachedExecutionFee, lzEndpointId, mintedBlock, validator
                ) {
                    emit TickerExecuted(tickerName, validator, mintedBlock, tickerTarget, lzEndpointId);

                    if (isDelegation) {
                        IDelegation(validator).snapshot(validatorName, _graffiti.validatorIndex, tickerTarget);
                    }
                } catch (bytes memory errorCode) {
                    emit TickerReverted(tickerName, tickerTarget, errorCode);
                    continue;
                }
            }

            ++totalOfExecutions_;
            emit BlockExecuted(mintedBlock, _graffiti.slotNumber, validator, _graffiti.graffitiText);
        }

        if (totalOfExecutions_ == 0) revert NoGraffitiExecution();

        lastBlockMinted = lastBlockMintedCached;

        _sendNative(treasury, address(this).balance, false);

        return totalOfExecutions_;
    }

    function callTicker(
        address _ticker,
        uint32 _gasLimit,
        uint128 _executionFee,
        uint32 _lzEndpointSelected,
        uint32 _blockNumber,
        address _identityReceiver
    ) external {
        if (msg.sender != address(this)) revert NoPermission();

        uint128 balanceBefore = uint128(address(this).balance);

        ITickerOperator(_ticker).onValidatorTriggered{ gas: _gasLimit }(
            _lzEndpointSelected, _blockNumber, _identityReceiver, _executionFee
        );

        uint128 balanceNow = uint128(address(this).balance) - balanceBefore;
        if (balanceNow < _executionFee) revert NotRefunded();
    }

    function updateGasLimitPerTicker(uint32 _gasPerTicker) external onlyOwner {
        if (_gasPerTicker < GAS_LIMIT_MINIMUM) revert GasLimitTooLow();

        gasLimitPerTicker = _gasPerTicker;
        emit GasPerTickerUpdated(_gasPerTicker);
    }

    function updateExecutionFee(uint128 _executionFee) external onlyOwner {
        executionFee = _executionFee;
        emit ExecutionFeeUpdated(_executionFee);
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

    function updateIdentityRouter(address _identityRouter) external onlyOwner {
        identityRouter = IdentityRouter(_identityRouter);
        emit IdentityRouterUpdated(_identityRouter);
    }

    function updateTickers(address _tickers) external onlyOwner {
        tickers = ITicker(_tickers);
        emit TickersUpdated(_tickers);
    }

    function withdrawETH(address _to) external onlyOwner {
        _sendNative(_to, address(this).balance, true);
    }

    receive() external payable { }
}
