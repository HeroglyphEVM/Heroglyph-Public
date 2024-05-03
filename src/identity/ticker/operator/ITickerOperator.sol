// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

/**
 * @title IGasPool
 * @notice If you have a community // service pool to pay all fee, it must have this interface integrated
 * @dev is the feePayer is not the contract address, it will fallback to calling IGasPool::payTo()
 */
interface IGasPool {
    function payTo(address _to, uint256 _amount) external;
}

interface ITickerOperator {
    error FailedToSendETH();
    error NotHeroglyph();

    event FeePayerUpdated(address indexed feePayer);

    /**
     * @notice onValidatorTriggered() Callback function when your ticker has been selectionned
     * @param _lzEndpointSelectionned // The selectionned layer zero endpoint target for this ticker
     * @param _blockNumber  // The number of the block minted
     * @param _validatorWithdrawer // The block miner address
     * @param _maxFeeCost // The max fee possible for executing this ticker
     * @dev be sure to apply onlyRelay to this function
     * @dev TIP: Avoid using reverts; instead, use return statements, unless you need to restore your contract to its
     * initial state.
     * @dev TIP:Keep in mind that a miner may utilize your ticker more than once in their graffiti. To avoid any
     * repetition, consider utilizing blockNumber to track actions.
     */
    function onValidatorTriggered(
        uint32 _lzEndpointSelectionned,
        uint32 _blockNumber,
        address _validatorWithdrawer,
        uint128 _maxFeeCost
    ) external;
}
