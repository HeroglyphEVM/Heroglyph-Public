// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IHeroglyphAttestation } from "./IHeroglyphAttestation.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SendNativeHelper } from "./SendNativeHelper.sol";

import { IValidatorIdentityV2 } from "./identity/wallet/v2/IValidatorIdentityV2.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title HeroglyphAttestation
 * @notice This contract serves as the reward mechanism for verified-attestor validators who have been selected.
 * To keep things batched and optimized, claiming starts a batch (if not already done) and will be executed only after
 * approximately 2 hours.
 * If for some reason the batch hasn't been executed after 4 hours, it can be triggered again.
 */
contract HeroglyphAttestation is IHeroglyphAttestation, ERC20, Ownable, SendNativeHelper, EIP712 {
    using EnumerableSet for EnumerableSet.UintSet;

    //keccak256("Redirect(address to,uint32 nonce,uint32 deadline)")
    bytes32 public constant PERMIT_TYPEHASH = 0x86f00204b857ac7ae88c83be689a16079dab37b4bb4cbd8791afa0840efc2638;

    // (EPOCH_30_DAYS / 100 + 1) --- Add one to loop
    uint32 public constant MAX_EPOCHS_LOOP = 68;
    uint32 public constant FINALIZED_EPOCH_DELAY = 25 minutes;
    uint32 public constant START_CLAIMING_EPOCH = 285_400;
    uint32 public constant EPOCH_30_DAYS = 6750;
    uint32 public constant START_CLAIMING_TIMESTAMP = 1_716_417_623;
    uint32 public constant MAX_EPOCHS = 100;
    uint32 public constant MAX_VALIDATORS = 100;
    uint32 public constant CLAIM_REQUEST_TIMEOUT = 4 hours;
    uint32 public constant IDLE_WAIT = 2 hours;

    IValidatorIdentityV2 public validatorIdentity;
    address public dedicatedMsgSender;
    uint32 public timePerEpoch;
    uint256 public attestationPointRate;
    uint256 public sendingBatchesSize;
    bool public isSoulbound;
    bool public pausePermit;

    mapping(uint32 validatorIndex => uint32 highestEpoch) internal latestEpochHeadRequested;
    mapping(uint32 headEpoch => uint64[]) internal headEpochBatchIds;
    mapping(uint32 validatorId => uint32) internal penalityPoints;
    mapping(address => bool) public hasTransferPermission;
    mapping(address => address) public redirectBadges;
    mapping(address => uint32) public redirectNonce;

    EnumerableSet.UintSet internal idleBatchIds;
    mapping(uint64 => BatchRequest) internal allBatches;
    uint64 public currentBatchId;

    modifier onlyDedicatedMsgSender() {
        if (msg.sender != dedicatedMsgSender) revert NotDedicatedMsgSender();
        _;
    }

    constructor(address _dedicatedMsgSender, address _validatorIdentity, address _owner)
        EIP712("HeroglyphAttestation", "v1")
        ERC20("Badges", "BADGES")
        Ownable(_owner)
    {
        dedicatedMsgSender = _dedicatedMsgSender;
        validatorIdentity = IValidatorIdentityV2(_validatorIdentity);

        // ~12 seconds per slot | 32 slots
        timePerEpoch = 12 * 32;

        //1 / (15 days / timePerEpoch)
        attestationPointRate = 0.000297 ether;
        sendingBatchesSize = 15;
        isSoulbound = true;
    }

    function createAttestationRequest(string[] calldata _identityNames) external {
        if (block.timestamp < START_CLAIMING_TIMESTAMP) revert CreateAttestationRequestIsNotActive();

        uint32 timePerEpochCached = timePerEpoch;

        uint32 epochHead;
        uint32 validatorIndex;
        uint64 batchId;
        uint32 expectedTimelapse;
        bool atLeastOneSuccess;

        uint32 tailEpoch = getTailEpoch();

        uint32 differenceEpoch;

        IValidatorIdentityV2.Identifier memory identity;

        for (uint256 i = 0; i < _identityNames.length; ++i) {
            identity = validatorIdentity.getIdentityData(0, _identityNames[i]);
            if (identity.walletReceiver == address(0)) continue;

            validatorIndex = identity.validatorUUID;

            epochHead = latestEpochHeadRequested[validatorIndex];
            if (epochHead < tailEpoch) epochHead = tailEpoch;

            for (uint256 j = 0; j < MAX_EPOCHS_LOOP; ++j) {
                differenceEpoch = (epochHead + MAX_EPOCHS) - START_CLAIMING_EPOCH;
                expectedTimelapse = (differenceEpoch * timePerEpochCached) + START_CLAIMING_TIMESTAMP;

                if (expectedTimelapse + FINALIZED_EPOCH_DELAY > block.timestamp) {
                    break;
                }

                epochHead += MAX_EPOCHS;
                batchId = _addReceiptToBatch(validatorIndex, epochHead);
                atLeastOneSuccess = true;

                emit ClaimRequest(validatorIndex, batchId, epochHead);
            }

            latestEpochHeadRequested[validatorIndex] = epochHead;
        }

        if (!atLeastOneSuccess) revert AttestationRequestFailed();
    }

    function _addReceiptToBatch(uint32 _validatorIndex, uint32 _head) internal returns (uint64 batchId_) {
        uint64[] storage headBatchIds = headEpochBatchIds[_head];
        BatchRequest storage epochBatch;
        uint64 batchIdsSize = uint64(headBatchIds.length);
        uint32 totalValidators;

        if (batchIdsSize == 0) {
            return _createNewBatch(_head, _validatorIndex);
        }

        batchId_ = headBatchIds[batchIdsSize - 1];
        epochBatch = allBatches[batchId_];

        if (epochBatch.success || epochBatch.expiredTime != 0) {
            return _createNewBatch(_head, _validatorIndex);
        }

        epochBatch.validators.push(_validatorIndex);
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

        ++currentBatchId;
        batchId_ = currentBatchId;

        allBatches[batchId_] = newBatch;
        headEpochBatchIds[_epochHead].push(batchId_);

        //No need to check for contains -> add already doing it
        idleBatchIds.add(batchId_);

        emit NewBatchCreated(_epochHead, batchId_);
        return batchId_;
    }

    function redirectClaimRewardsWithPermit(
        address _withdrawalCredential,
        address _to,
        uint32 _nonce,
        uint32 _deadline,
        bytes calldata _signature
    ) external {
        if (pausePermit) revert PermitPaused();
        if (block.timestamp > _deadline) revert ExpiredSignature();

        uint32 currentNonce = redirectNonce[_withdrawalCredential] + 1;
        if (_nonce != currentNonce) revert InvalidRedirectNonce();

        redirectNonce[_withdrawalCredential] = currentNonce;

        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(PERMIT_TYPEHASH, _to, currentNonce, _deadline)));

        if (!SignatureChecker.isValidSignatureNow(_withdrawalCredential, digest, _signature)) {
            revert InvalidSignature();
        }

        redirectBadges[_withdrawalCredential] = _to;
        emit RedirectionSet(_withdrawalCredential, _to, currentNonce);
    }

    function redirectClaimRewards(address _to) external {
        redirectBadges[msg.sender] = _to;
        emit RedirectionSet(msg.sender, _to, 0);
    }

    function manuallyExecuteBatch(uint64 batchId) external {
        _manuallyExecuteBatch(batchId, true);
    }

    function manuallyExecuteBatches(uint64[] calldata batchIds) external {
        bool atLeastOneSuccess;
        bool result;

        for (uint256 i = 0; i < batchIds.length; ++i) {
            result = _manuallyExecuteBatch(batchIds[i], false);

            if (!atLeastOneSuccess) atLeastOneSuccess = result;
        }

        if (!atLeastOneSuccess) revert NothingToExecute();
    }

    function _manuallyExecuteBatch(uint64 _batchId, bool _allowsRevert) internal returns (bool success_) {
        BatchRequest storage batch = allBatches[_batchId];
        if (batch.headEpoch == 0) {
            if (_allowsRevert) revert BatchNotFound();
            return false;
        }
        if (batch.expiredTime > block.timestamp || batch.idleEnd > block.timestamp) {
            if (_allowsRevert) revert BatchNotSentOrExpired();
            return false;
        }
        if (batch.success) {
            if (_allowsRevert) revert BatchAlreadyExecuted();
            return false;
        }

        _sendBatchToExecute(batch, _batchId);
        return true;
    }

    function checkerToExecuteIdles() external view returns (bool canExec, bytes memory execPayload) {
        uint256 pendingLength = idleBatchIds.length();

        canExec = pendingLength > 0;
        execPayload = abi.encodeCall(HeroglyphAttestation.tryExecutingIdleBatches, (pendingLength));

        return (canExec, execPayload);
    }

    function tryExecutingIdleBatches(uint256 _loop) external {
        uint256[] memory cachedBatchIds = idleBatchIds.values();
        uint256 totalPending = cachedBatchIds.length;
        uint256 maxLoop = sendingBatchesSize;

        if (_loop > maxLoop) _loop = maxLoop;
        if (_loop == 0 || _loop > totalPending) _loop = totalPending;

        bool atLeastOneTriggered;

        BatchRequest storage batch;
        uint64 batchId;
        for (uint256 i = 0; i < _loop; ++i) {
            batchId = uint64(cachedBatchIds[i]);
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

        if (batch.headEpoch == 0) revert BatchNotFound();
        if (batch.success) revert BatchAlreadyExecuted();
        if (_withdrawalAddresses.length != totalValidators || _attestationPoints.length != totalValidators) {
            revert MismatchArrays();
        }

        batch.success = true;

        uint32 validatorIndex;
        address withdrawal;
        int32 attestationPoint;
        for (uint256 i = 0; i < _withdrawalAddresses.length; ++i) {
            validatorIndex = batch.validators[i];
            withdrawal = _withdrawalAddresses[i];
            attestationPoint = _attestationPoints[i];

            _executeSingleClaim(validatorIndex, withdrawal, attestationPoint);

            emit ExecutionAttestationClaim(
                _batchId, validatorIndex, withdrawal, attestationPoint, penalityPoints[validatorIndex]
            );
        }

        emit BatchExecuted(_batchId, _attestationPoints);
    }

    function _executeSingleClaim(uint32 _validator, address _withdrawalAddress, int32 _attestationPoint) internal {
        address redirectedAddress = redirectBadges[_withdrawalAddress];

        if (redirectedAddress != address(0)) {
            _withdrawalAddress = redirectedAddress;
        }

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

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);

        if ((from == address(0) || to == address(0)) || !isSoulbound) return;
        if (!hasTransferPermission[msg.sender]) revert TokenSoulbound();
    }

    function setTransferPermissionOf(address _target, bool _enabled) external onlyOwner {
        hasTransferPermission[_target] = _enabled;
        emit TransferPermissionUpdated(_target, _enabled);
    }

    function updateDedicatedMsgSender(address _msg) external onlyOwner {
        dedicatedMsgSender = _msg;
        emit DedicatedMsgSenderUpdated(_msg);
    }

    function updateValidatorIdentity(address _validatorIdentity) external onlyOwner {
        validatorIdentity = IValidatorIdentityV2(_validatorIdentity);
        emit ValidatorIdentityUpdated(_validatorIdentity);
    }

    function updateAttestationPointRate(uint256 _rate) external onlyOwner {
        attestationPointRate = _rate;
        emit AttestationPointRateUpdated(_rate);
    }

    function updateTimePerEpoch(uint32 _perEpochInSeconds) external onlyOwner {
        timePerEpoch = _perEpochInSeconds;
        emit TimePerEpochUpdated(_perEpochInSeconds);
    }

    function updateSendingBatchesSize(uint256 _size) external onlyOwner {
        sendingBatchesSize = _size;
        emit SendingBatchesSizeUpdated(_size);
    }

    function updateSoulboundStatus(bool _isSoulbound) external onlyOwner {
        isSoulbound = _isSoulbound;
        emit SoulboundStatusUpdated(_isSoulbound);
    }

    function updatePausePermit(bool _status) external onlyOwner {
        pausePermit = _status;
        emit PermitPausedUpdated(_status);
    }

    function getDomainSeparatorV4() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function getTailEpoch() public view returns (uint32 tail_) {
        if (block.timestamp <= START_CLAIMING_TIMESTAMP) return START_CLAIMING_EPOCH;

        uint256 fromTheStart = (block.timestamp - START_CLAIMING_TIMESTAMP) / timePerEpoch;
        uint256 ceil = (fromTheStart + START_CLAIMING_EPOCH - EPOCH_30_DAYS) / MAX_EPOCHS;

        tail_ = uint32(ceil * MAX_EPOCHS);
        return (tail_ < START_CLAIMING_EPOCH) ? START_CLAIMING_EPOCH : tail_;
    }

    function getValidatorLatestEpochClaimed(uint32 _validatorIndex) external view returns (uint256 latest_) {
        latest_ = latestEpochHeadRequested[_validatorIndex];
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
