// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

interface IValidatorIdentityV2 {
    error NoMigrationPossible();
    error NotBackwardCompatible();
    error MsgValueTooLow();
    error NoNeedToPay();
    error InvalidBPS();

    /**
     * @notice Identifier
     * @param name Name of the Wallet
     * @param walletReceiver Address that will be receiving Ticker's reward if any
     */
    struct Identifier {
        string name;
        uint32 validatorUUID;
        address walletReceiver;
    }

    event WalletReceiverUpdated(uint256 indexed walletId, string indexed identityName, address newWallet);
    event NewGraffitiIdentityCreated(
        uint256 indexed walletId, uint32 indexed validatorId, string identityName, uint256 cost
    );
    event MaxIdentityPerDayAtInitialPriceUpdated(uint32 maxIdentityPerDayAtInitialPrice);
    event PriceIncreaseThresholdUpdated(uint32 priceIncreaseThreshold);
    event PriceDecayBPSUpdated(uint32 priceDecayBPS);

    /**
     * isSoulboundIdentity Try to soulbound an identity
     * @param _name Name of the identity
     * @param _validatorId Validator ID of the validator
     * @return bool Returns true if the identity is soulbound & validatorId is the same
     */
    function isSoulboundIdentity(string calldata _name, uint32 _validatorId) external view returns (bool);

    /**
     * migrateFromOldIdentity Migrate from old identity to new identity
     * @param _name Name of the identity
     * @param _validatorId Validator ID of the validator
     */
    function migrateFromOldIdentity(string calldata _name, uint32 _validatorId) external;

    /**
     * create Create an Identity
     * @param _name name of the Identity
     * @param _validatorId Unique Id of the validator
     */
    function create(string calldata _name, address _receiverWallet, uint32 _validatorId) external payable;

    /**
     * updateReceiverAddress Update Receiver Wallet of an Identity
     * @param _nftId The ID of the NFT.
     * @param _name The name of the identity.
     * @param _receiver address that will be receiving any rewards
     * @dev Use either `_nftId` or `_name`. If you want to use `_name`, set `_nftId` to 0.
     * @dev Only the owner of the Identity can call this function
     */
    function updateReceiverAddress(uint256 _nftId, string memory _name, address _receiver) external;

    /**
     * getIdentityDataWithName Get Identity information with name
     * @param _nftId The ID of the NFT.
     * @param _name The name of the identity.
     * @return identity_ tuple(name,tokenReceiver)
     * @dev Use either `_nftId` or `_name`. If you want to use `_name`, set `_nftId` to 0.
     */
    function getIdentityData(uint256 _nftId, string calldata _name) external view returns (Identifier memory);
}
