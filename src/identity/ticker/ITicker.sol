// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

interface ITicker {
    error ProtectionStillActive();
    error TickerNotFound();
    error CantSelfBuy();
    error PriceTooLow();
    error ProtectionMinimumOneMinute();
    error TickerIsImmune();
    error TickerUnderWater();
    error FrontRunGuard();
    error InitializationPeriodActive();

    event TickerUpdated(uint256 indexed id, string indexed name, address executionContract, uint256 price);
    event TickerHijacked(
        uint256 indexed id,
        string indexed name,
        address indexed hijacker,
        uint256 boughtValue,
        uint256 sentToPreviousOwner
    );
    event AddedDepositToTicker(uint256 indexed id, string indexed name, uint128 totalDeposit, uint128 added);
    event WithdrawnFromTicker(uint256 indexed id, string indexed name, uint128 totalDeposit, uint128 removed);
    event TickerSurrendered(uint256 indexed id, string indexed name, address indexed prevOwner);
    event TaxPaid(uint256 indexed id, string indexed name, uint256 paid, uint256 depositBalance, uint32 timestamp);
    event ProtectionTimeUpdated(uint32 time);

    /**
     * @notice TickerMetadata
     * @param name Name of the Ticker
     * @param contractTarget Contract Targeted by this ticker
     * @param owningDate date in second of when the owner received the ownership of the ticker
     * @param lastTimeTaxPaid Last time the tax has been paid
     * @param immunityEnds *Only for Heroglyph* Adds immunity on creation to protect against the tax & the hijack
     * @param price The price the owner is ready to sell it's ticker, the tax is based on this price
     */
    struct TickerMetadata {
        string name;
        address contractTarget;
        uint32 owningDate;
        uint32 lastTimeTaxPaid;
        uint32 immunityEnds;
        uint128 price;
        uint128 deposit;
    }

    /**
     * @notice TickerCreation
     * @param name Name of the Ticker
     * @param contractTarget Contract Targeted by this ticker
     * @param gasLimit  Gas Limit of the execution, it's capped to the limit set by HeroglyphRelay::tickerGasLimit
     * @param setPrice The price the owner is ready to sell it's ticker, the tax is based on this price
     */
    struct TickerCreation {
        string name;
        address contractTarget;
        uint128 setPrice;
    }

    /**
     * @notice create Create an Identity
     * @param _tickerCreation tuple(string name, uint128 setPrice, address contractTarget, uint128 gasLimit)
     */
    function create(TickerCreation calldata _tickerCreation) external payable;

    /**
     * @notice updateTicker Update Ticker settings
     * @param _nftId Id of the Ticker NFT
     * @param _name Name of the Ticker
     * @param _contractTarget contract target
     * @dev Only the Ticker Owner can call this function
     * @dev if `_nftId` is zero, it will use `_name` instead
     */
    function updateTicker(uint256 _nftId, string calldata _name, address _contractTarget) external;

    /**
     * @notice hijack Buy a Ticker and set the new price
     * @param _nftId Id of the Ticker NFT
     * @param _name  name of the Ticker
     * @param _tickerPrice price of the ticker before hijack
     * @param _newPrice new price after hijackout
     * @dev if `_nftId` is zero, it will use `_name` instead
     */
    function hijack(uint256 _nftId, string calldata _name, uint128 _tickerPrice, uint128 _newPrice) external payable;

    /**
     * @notice updatePrice Update the price of a Ticker
     * @param _nftId Id of the Ticker NFT
     * @param _name Name of the Ticker
     * @param _newPrice New price of the Ticker
     * @dev Only the Ticker owner can update the price
     * @dev if `_nftId` is zero, it will use `_name` instead
     */
    function updatePrice(uint256 _nftId, string calldata _name, uint128 _newPrice) external;

    /**
     * @notice increaseDeposit Increase the deposit on a ticker to avoid losing it from tax
     * @param _nftId Id of the Ticker NFT
     * @param _name Name of the ticker
     * @dev only Ticker Owner can call this
     * @dev if `_nftId` is zero, it will use `_name` instead
     */
    function increaseDeposit(uint256 _nftId, string calldata _name) external payable;

    /**
     * @notice withdrawDeposit Withdraw deposit from Ticker
     * @param _nftId Id of the Ticker NFT
     * @param _name Name of the Ticker
     * @param _amount Amount to withdraw
     * @dev Only Ticker owner can call this function
     * @dev If the new deposit balance is lower than the tax or equals to zero the owner will lose their Ticker and the
     * new price of the Ticker will be zero
     * @dev if `_nftId` is zero, it will use `_name` instead
     * @dev if `_amount` is zero, it will withdraw all the deposit remaining
     */
    function withdrawDeposit(uint256 _nftId, string calldata _name, uint128 _amount) external;

    /**
     * @notice getDepositLeft() Get the deposit left after tax
     * @param _nftId Id of the Ticker NFT
     * @param _name Name of the Ticker
     * @dev if `_nftId` is zero, it will use `_name` instead
     */
    function getDepositLeft(uint256 _nftId, string calldata _name) external view returns (uint256 _left);

    /**
     * @notice getTaxDue() Get how much the Ticker is due on their taxes
     * @param _nftId Id of the Ticker NFT
     * @param _name Name of the Ticker
     * @dev if `_nftId` is zero, it will use `_name` instead
     */
    function getTaxDue(uint256 _nftId, string calldata _name) external view returns (uint256 _tax);

    /**
     * @notice getDeposit Get how many eth has been deposited for a Ticker
     * @param _nftId Id of the Ticker NFT
     * @param _name Name of the Ticker
     * @dev if `_nftId` is zero, it will use `_name` instead
     */
    function getDeposit(uint256 _nftId, string calldata _name) external view returns (uint256);

    /**
     * @notice getTickerMetadata Get Ticker Metadata and its status
     * @param _nftId Id of the Ticker NFT
     * @param _name Name of the Ticker
     * @return ticker_ tuple(string name, uint128 setPrice, address contractTarget, uint128 gasLimit)
     * @return shouldBeSurrender_ If it's true, the ticker will be surrendered. The only way to avoid this is if the
     * owner
     * calls deposit before any action.
     * @dev if `_nftId` is zero, it will use `_name` instead
     */
    function getTickerMetadata(uint256 _nftId, string calldata _name)
        external
        view
        returns (TickerMetadata memory ticker_, bool shouldBeSurrender_);
}
