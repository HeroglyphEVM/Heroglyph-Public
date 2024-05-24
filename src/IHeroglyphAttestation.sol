// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

interface IHeroglyphAttestation {
    error NothingToExecute();
    error NotDedicatedMsgSender();
    error AttestationRequestFailed();
    error BatchNotSentOrExpired();
    error BatchAlreadyExecuted();
    error MismatchArrays();
    error CreateAttestationRequestIsNotActive();
    error TokenSoulbound();
    error ExpiredSignature();
    error InvalidSignature();
    error BatchNotFound();
    error PermitPaused();
    error InvalidRedirectNonce();

    struct BatchRequest {
        uint32 headEpoch;
        uint32[] validators;
        uint32 idleEnd;
        uint32 expiredTime;
        bool success;
    }

    event DedicatedMsgSenderUpdated(address indexed dedicatedMsgSender);
    event NoWithdrawalAddressFound(uint32 indexed validator, uint256 rewards);
    event SendBatchToExecute(uint64 indexed batchId, uint32 indexed headEpoch, uint32[] validators);
    event ClaimRequest(uint32 indexed validatorId, uint64 indexed batchId, uint32 indexed headEpoch);
    event ExecutionAttestationClaim(
        uint64 indexed batchId,
        uint32 indexed validatorId,
        address indexed withdrawalAddress,
        int32 receivedPoints,
        uint32 penaltyBalance
    );
    event NewBatchCreated(uint32 indexed headEpoch, uint64 indexed batchId);
    event AttestationPointRateUpdated(uint256 newRate);
    event TimePerEpochUpdated(uint256 timePerEpochInSeconds);
    event BatchExecuted(uint64 indexed batchId, int32[] attestationPoints);
    event ValidatorIdentityUpdated(address validatorIdentity);
    event SendingBatchesSizeUpdated(uint256 size);
    event TransferPermissionUpdated(address indexed target, bool status);
    event RedirectionSet(address indexed withdrawalCredential, address indexed to, uint32 nonce);
    event SoulboundStatusUpdated(bool isSoulbound);
    event PermitPausedUpdated(bool status);
}
