// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

interface IHeroglyphRelay {
    error EmptyGraffities();
    error NoGraffitiExecution();
    error NoPermission();
    error NullAddress();
    error NotRefunded();
    error NotDedicatedMsgSender();
    error GasLimitTooLow();
    error MissingTreasury();
    error InvalidEpoch();
    error LowerThanCurrentEpoch();
    error CannotBeZero();

    event BlockExecuted(
        uint32 indexed blockNumber, uint32 indexed slotNumber, address indexed validator, string graffiti
    );
    event TickerReverted(string indexed tickerName, address indexed contractTarget, bytes error);
    event TickerExecuted(
        string indexed tickerName,
        address indexed validatorWithdrawer,
        uint256 indexed blockNumber,
        address linkedContract,
        uint32 lzEndpointSelectionned
    );
    event CostPerUnitUpdated(uint256 cost);
    event GasPerUnitUpdated(uint128 gasPerUnit);
    event ExtraGasCreditUpdate(uint128 gasCredit);
    event GasLimitUpdated(uint32 gasLimit);
    event DedicatedMsgSenderUpdated(address indexed dedicatedMsgSender);
    event TreasuryUpdated(address indexed treasury);

    struct AttestationEpoch {
        uint32[] blockNumbers;
        bytes32[] blockAttestorsRoot;
        bool isCompleted;
    }

    struct GraffitiData {
        string validatorName; // validator identity name
        string[] tickers; // tickers in the graffiti, can be empty
        uint32[] lzEndpointTargets; //lzEndpointTargets for each tickers
        uint32 mintedBlock; // block minted
        uint32 slotNumber; // Slot of the block
        string graffitiText;
    }

    /**
     * @notice executeRelay is the bridge between off-chain and on-chain. It will only be called if the produced
     * block contains our graffiti. It executes the tickers' code and reward the attestors.
     * @param _graffities grafiti metadata
     * @dev can only be called by the Dedicated Sender
     */
    function executeRelay(GraffitiData[] calldata _graffities) external returns (uint256 totaltOfExecutions_);

    /**
     * @notice Call Ticker to execute its logic
     * @param _ticker Ticker Address
     * @param _gasLimit Gas Limit, it cannot exceed `tickerGasLimit` but can be lower
     * @param _lzEndpointSelectionned the LZ endpoint selectionned for this ticker
     * @param _blockNumber the minted block number
     * @param _validatorWithdrawer the miner
     * @dev We use public function to catch reverts without stopping the whole flow
     * @dev can only be called by itself
     */
    function callTicker(
        address _ticker,
        uint32 _gasLimit,
        uint32 _lzEndpointSelectionned,
        uint32 _blockNumber,
        address _validatorWithdrawer
    ) external;

    /**
     * @notice getExecutionNativeFee get how much fee the Ticker is due
     * @param _addExtra Adds Extra gas to be sure you don't
     */
    function getExecutionNativeFee(uint128 _addExtra) external view returns (uint128 fee_);
}
