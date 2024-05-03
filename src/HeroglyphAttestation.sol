// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IHeroglyphAttestation } from "./IHeroglyphAttestation.sol";
import { OFT } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SendNativeHelper } from "./SendNativeHelper.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title HeroglyphAttestation
 * @notice This contract serves as the reward mechanism for verified-attestor validators who have been selected.
 * To keep things batched and optimized, claiming starts a batch (if not already done) and will be executed only after
 * approximately 3 days.
 * If for some reason the batch hasn't been executed after 2 days, it can be triggered again.
 */
contract HeroglyphAttestation is IHeroglyphAttestation, OFT, SendNativeHelper {
    using EnumerableSet for EnumerableSet.UintSet;

    uint32 public constant FINALIZED_EPOCH_DELAY = 25 minutes;
    uint32 public constant START_CLAIMING_EPOCH = 281_000;
    uint32 public constant EPOCH_30_DAYS = 6725;
    uint32 public constant START_CLAIMING_TIMESTAMP = 1_714_728_023;
    uint32 public constant MAX_EPOCHS = 100;
    uint32 public constant MAX_VALIDATORS = 100;
    uint32 public constant CLAIM_REQUEST_TIMEOUT = 4 hours;
    uint32 public constant IDLE_WAIT = 2 hours;

    address public dedicatedMsgSender;
    uint32 public timePerEpoch;
    uint256 public attestationPointRate;

    mapping(uint32 validatorId => uint32 highestEpoch) internal latestEpochHeadRequested;
    mapping(uint32 headEpoch => uint64[]) internal headEpochBatchIds;
    mapping(uint32 validatorId => uint32) internal penalityPoints;

    EnumerableSet.UintSet internal idleBatchIds;
    BatchRequest[] internal allBatches;

    modifier onlyDedicatedMsgSender() {
        if (msg.sender != dedicatedMsgSender) revert NotDedicatedMsgSender();
        _;
    }

    constructor(address _dedicatedMsgSender, address _lzEndpoint, address _delegate)
        OFT("Badges", "$BADGES", _lzEndpoint, _delegate)
        Ownable(_delegate)
    {
        dedicatedMsgSender = _dedicatedMsgSender;

        // ~12 seconds per slot | 32 slots
        timePerEpoch = 12 * 32;

        attestationPointRate = 1e18;

        allBatches.push(
            BatchRequest({
                headEpoch: START_CLAIMING_EPOCH,
                validators: new uint32[](0),
                idleEnd: 0,
                expiredTime: START_CLAIMING_TIMESTAMP,
                success: true
            })
        );
    }

    function createAttestationRequest(uint32[] calldata _validatorIds) external {
        if (block.timestamp < START_CLAIMING_TIMESTAMP) revert CreateAttestationRequestIsNotActive();

        uint32 epochHead;
        uint32 latestEpoch;
        uint32 validatorId;
        uint64 batchId;

        bool atLeastOneSuccess;

        uint32 tailEpoch = getTailEpoch();

        for (uint256 i = 0; i < _validatorIds.length; ++i) {
            validatorId = _validatorIds[i];
            latestEpoch = latestEpochHeadRequested[validatorId];
            if (latestEpoch < tailEpoch) latestEpoch = tailEpoch;

            epochHead = latestEpoch + MAX_EPOCHS;
            uint32 expectedTimelapse = ((epochHead - START_CLAIMING_EPOCH) * timePerEpoch) + START_CLAIMING_TIMESTAMP;

            if (expectedTimelapse + FINALIZED_EPOCH_DELAY > block.timestamp) {
                continue;
            }

            latestEpochHeadRequested[validatorId] = epochHead;
            batchId = _addReceiptToBatch(validatorId, epochHead);
            atLeastOneSuccess = true;

            emit ClaimRequest(validatorId, batchId, epochHead);
        }

        if (!atLeastOneSuccess) revert AttestationRequestFailed();
    }

    function _addReceiptToBatch(uint32 _validatorId, uint32 _head) internal returns (uint64 batchId_) {
        uint64[] storage headBatchIds = headEpochBatchIds[_head];
        BatchRequest storage epochBatch;
        uint64 batchIdsSize = uint64(headBatchIds.length);
        uint32 totalValidators;

        if (batchIdsSize == 0) {
            return _createNewBatch(_head, _validatorId);
        }

        batchId_ = headBatchIds[batchIdsSize - 1];
        epochBatch = allBatches[batchId_];

        if (epochBatch.success || epochBatch.expiredTime != 0) {
            return _createNewBatch(_head, _validatorId);
        }

        epochBatch.validators.push(_validatorId);
        totalValidators = uint32(epochBatch.validators.length);

        if (totalValidators == MAX_VALIDATORS || epochBatch.idleEnd <= block.timestamp) {
            _sendBatchToExecute(epochBatch, batchId_);
        }

        return batchId_;
    }

    function _createNewBatch(uint32 _epochHead, uint32 _validatorToAdd) internal returns (uint64 batchId_) {
        BatchRequest memory newBatch = BatchRequest({
            headEpoch: _epochHead,
            validators: new uint32[](1),
            idleEnd: uint32(block.timestamp) + IDLE_WAIT,
            expiredTime: 0,
            success: false
        });

        newBatch.validators[0] = _validatorToAdd;

        batchId_ = uint64(allBatches.length);
        allBatches.push(newBatch);
        headEpochBatchIds[_epochHead].push(batchId_);

        //No need to check for contains -> add already doing it
        idleBatchIds.add(batchId_);

        emit NewBatchCreated(_epochHead, batchId_);
        return batchId_;
    }

    function manuallyExecuteBatch(uint64 batchId) external {
        BatchRequest storage batch = allBatches[batchId];
        if (batch.expiredTime > block.timestamp || batch.idleEnd > block.timestamp) {
            revert BatchNotSentOrExpired();
        }
        if (batch.success) revert BatchAlreadyExecuted();

        _sendBatchToExecute(batch, batchId);
    }

    function tryExecutingIdleBatches(uint256 _loop) external {
        uint256[] memory cachedBatchIds = idleBatchIds.values();
        uint256 totalPending = cachedBatchIds.length;
        if (_loop == 0 || _loop > totalPending) _loop = totalPending;

        bool atLeastOneTriggered;

        BatchRequest storage batch;
        uint256 batchId;
        for (uint256 i = 0; i < _loop; ++i) {
            batchId = cachedBatchIds[i];
            batch = allBatches[batchId];
            if (batch.expiredTime > block.timestamp || batch.idleEnd > block.timestamp) continue;

            _sendBatchToExecute(batch, uint64(batchId));
            atLeastOneTriggered = true;
        }

        if (!atLeastOneTriggered) revert NothingToExecute();
    }

    function _sendBatchToExecute(BatchRequest storage _batch, uint64 _batchId) internal {
        _batch.expiredTime = uint32(block.timestamp) + CLAIM_REQUEST_TIMEOUT;

        //No need to check for contains -> remove's checking it
        idleBatchIds.remove(_batchId);

        emit SendBatchToExecute(_batchId, _batch.headEpoch, _batch.validators);
    }

    function executeClaiming(
        uint64 _batchId,
        address[] calldata _withdrawalAddresses,
        int32[] calldata _attestationPoints
    ) external onlyDedicatedMsgSender {
        BatchRequest storage batch = allBatches[_batchId];
        uint256 totalValidators = batch.validators.length;

        if (batch.success) revert BatchAlreadyExecuted();
        if (_withdrawalAddresses.length != totalValidators || _attestationPoints.length != totalValidators) {
            revert MismatchArrays();
        }

        batch.success = true;

        uint32 validatorId;
        address withdrawal;
        int32 attestationPoint;
        for (uint256 i = 0; i < _withdrawalAddresses.length; ++i) {
            validatorId = batch.validators[i];
            withdrawal = _withdrawalAddresses[i];
            attestationPoint = _attestationPoints[i];

            _executeSingleClaim(validatorId, withdrawal, attestationPoint);

            emit ExecutionAttestationClaim(
                _batchId, validatorId, withdrawal, attestationPoint, penalityPoints[validatorId]
            );
        }
    }

    function _executeSingleClaim(uint32 _validator, address _withdrawalAddress, int32 _attestationPoint) internal {
        uint32 penaltyPoints = penalityPoints[_validator];
        if (_attestationPoint == 0) {
            return;
        }

        if (_attestationPoint < 0) {
            penalityPoints[_validator] += uint32(_attestationPoint * -1);
            return;
        }
        uint32 pointUint32 = uint32(_attestationPoint);

        if (penaltyPoints >= pointUint32) {
            penaltyPoints -= pointUint32;
            pointUint32 = 0;
        } else {
            pointUint32 -= penaltyPoints;
            penaltyPoints = 0;
        }

        penalityPoints[_validator] = penaltyPoints;
        if (pointUint32 == 0) return;

        uint256 reward = uint256(pointUint32) * attestationPointRate;

        if (reward == 0) return;

        if (_withdrawalAddress != address(0)) {
            _mint(_withdrawalAddress, reward);
            return;
        }

        _mint(owner(), reward);
        emit NoWithdrawalAddressFound(_validator, reward);
    }

    function updateDedicatedMsgSender(address _msg) external onlyOwner {
        dedicatedMsgSender = _msg;
        emit DedicatedMsgSenderUpdated(_msg);
    }

    function updateAttestationPointRate(uint256 _rate) external onlyOwner {
        attestationPointRate = _rate;
        emit AttestationPointRateUpdated(_rate);
    }

    function updateTimePerEpoch(uint32 _perEpochInSeconds) external onlyOwner {
        timePerEpoch = _perEpochInSeconds;
        emit TimePerEpochUpdated(_perEpochInSeconds);
    }

    function getTailEpoch() public view returns (uint32 tail_) {
        if (block.timestamp <= START_CLAIMING_TIMESTAMP) return START_CLAIMING_EPOCH;

        uint256 fromTheStart = (block.timestamp - START_CLAIMING_TIMESTAMP) / timePerEpoch;
        uint256 ceil = (fromTheStart + START_CLAIMING_EPOCH - EPOCH_30_DAYS) / MAX_EPOCHS;

        tail_ = uint32(ceil * MAX_EPOCHS);
        return (tail_ < START_CLAIMING_EPOCH) ? START_CLAIMING_EPOCH : tail_;
    }

    function getValidatorLatestEpochClaimed(uint32 _validatorId) external view returns (uint256 latest_) {
        latest_ = latestEpochHeadRequested[_validatorId];
        uint32 tails = getTailEpoch();

        return (latest_ > tails) ? latest_ : tails;
    }

    function getEpochHeadRequestBatchIds(uint32 _epochHead) external view returns (uint64[] memory) {
        return headEpochBatchIds[_epochHead];
    }

    function getBatchRequest(uint64 _batchId) external view returns (BatchRequest memory) {
        return allBatches[_batchId];
    }

    function getIdleRequestBatches() external view returns (uint256[] memory) {
        return idleBatchIds.values();
    }

    function getPenaltyPointBalance(uint32 _validatorId) external view returns (uint256) {
        return penalityPoints[_validatorId];
    }
}
