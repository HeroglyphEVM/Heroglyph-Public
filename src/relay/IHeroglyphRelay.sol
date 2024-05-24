// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

interface IHeroglyphRelay {
    error EmptyGraffities();
    error NoGraffitiExecution();
    error NoPermission();
    error NotRefunded();
    error NotDedicatedMsgSender();
    error MissingTreasury();
    error GasLimitTooLow();

    event BlockExecuted(
        uint32 indexed blockNumber, uint32 indexed slotNumber, address indexed validator, string graffiti
    );
    event TickerReverted(string indexed tickerName, address indexed contractTarget, bytes error);
    event TickerExecuted(
        string indexed tickerName,
        address indexed validatorWithdrawer,
        uint256 indexed blockNumber,
        address linkedContract,
        uint32 lzEndpointSelected
    );
    event ExecutionFeeUpdated(uint128 _fee);
    event GasPerTickerUpdated(uint32 _gas);
    event DedicatedMsgSenderUpdated(address indexed dedicatedMsgSender);
    event TreasuryUpdated(address indexed treasury);
    event IdentityRouterUpdated(address identityRouter);
    event TickersUpdated(address tickers);

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
        uint32 validatorIndex;
    }

    /**
     * @notice executeRelay is the bridge between off-chain and on-chain. It will only be called if the produced
     * block contains our graffiti. It executes the tickers' code and reward the attestors.
     * @param _graffities graffiti metadata
     * @dev can only be called by the Dedicated Sender
     */
    function executeRelay(GraffitiData[] calldata _graffities) external returns (uint256 totalOfExecutions_);

    /**
     * @notice Call Ticker to execute its logic
     * @param _ticker Ticker Address
     * @param _gasLimit Gas Limit, it cannot exceed `tickerGasLimit` but can be lower
     * @param _blockNumber the minted block number
     * @param _lzEndpointSelected the LZ endpoint selected for this ticker
     * @param _executionFee Execution Fee to repay
     * @param _identityReceiver the miner
     * @dev We use public function to catch reverts without stopping the whole flow
     * @dev can only be called by itself
     */
    function callTicker(
        address _ticker,
        uint32 _gasLimit,
        uint128 _executionFee,
        uint32 _lzEndpointSelected,
        uint32 _blockNumber,
        address _identityReceiver
    ) external;
}
