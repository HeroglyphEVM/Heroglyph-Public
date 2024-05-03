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
        address indexed withdrawer,
        int32 attestationPoint,
        uint32 penaltyBalance
    );
    event NewBatchCreated(uint32 indexed headEpoch, uint64 indexed batchId);
    event AttestationPointRateUpdated(uint256 newRate);
    event TimePerEpochUpdated(uint256 timePerEpochInSeconds);
}
