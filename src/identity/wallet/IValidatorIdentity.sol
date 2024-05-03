// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

interface IValidatorIdentity {
    error EarlyBirdOnly();
    error InvalidProof();

    /**
     * @notice Identifier
     * @param name Name of the Wallet
     * @param tokenReceiver Address that will be receiving Ticker's reward if any
     */
    struct Identifier {
        string name;
        address tokenReceiver;
    }

    /**
     * @notice DelegatedIdentity
     * @param isEnabled If the Delegation is enabled
     * @param owner The original owner of the Identity
     * @param originalTokenReceiver The original Identifier::tokenReceiver
     * @param delegatee The one buying the delegation
     * @param durationInMonths The duration in months of the delegation
     * @param endDelegationTime The time when the bought delegation ends
     * @param cost The upfront cost of the delegation
     */
    struct DelegatedIdentity {
        bool isEnabled;
        address owner;
        address originalTokenReceiver;
        address delegatee;
        uint8 durationInMonths;
        uint32 endDelegationTime;
        uint128 cost;
    }

    error NotSigner();
    error ExpiredSignature();

    error DelegationNotOver();
    error DelegationNotActive();
    error DelegationOver();
    error NotDelegatee();
    error NotPaid();
    error InvalidMonthTime();

    event TokenReceiverUpdated(uint256 indexed walletId, string indexed walletName, address newTokenReceiver);
    event DelegationUpdated(string indexed identity, uint256 indexed nftId, bool isEnabled);
    event IdentityDelegated(
        string indexed identity, uint256 indexed nftId, address indexed delegatee, uint32 endPeriod
    );

    /**
     * createWithSignature Create an Identity with signature to avoid getting front-runned
     * @param _name Name of the Identity
     * @param _receiverWallet Wallet that will be receiving the rewards
     * @param _deadline Deadline of the signature
     * @param _signature signed message abi.encodePacket(userAddress,name,deadline)
     */
    function createWithSignature(
        string calldata _name,
        address _receiverWallet,
        uint256 _deadline,
        bytes memory _signature
    ) external payable;

    /**
     * create Create an Identity
     * @param _name name of the Identity
     * @param _receiverWallet Wallet that will be receiving the rewards
     */
    function create(string calldata _name, address _receiverWallet) external payable;

    /**
     * @notice delegate Send temporary your nft away to let other user use it for a period of time
     * @param _nftId The ID of the NFT.
     * @param _name The name of the identity.
     * @param _delegateCost cost to accept this delegation
     * @param _amountOfMonths term duration in months
     * @dev Use either `_nftId` or `_name`. If you want to use `_name`, set `_nftId` to 0.
     */
    function delegate(uint256 _nftId, string memory _name, uint128 _delegateCost, uint8 _amountOfMonths) external;

    /**
     * @notice acceptDelegation Accept a delegation to use it for yourself during the set period defined
     * @param _nftId The ID of the NFT.
     * @param _name The name of the identity.
     * @param _receiverWallet wallet you want the token(s) to be minted to
     * @dev Use either `_nftId` or `_name`. If you want to use `_name`, set `_nftId` to 0.
     */
    function acceptDelegation(uint256 _nftId, string memory _name, address _receiverWallet) external payable;
    /**
     * @notice toggleDelegation Disable/Enable your delegation, so if it's currently used, nobody won't be able to
     * accept it
     * when the term ends
     * @param _nftId The ID of the NFT.
     * @param _name The name of the identity.
     * @dev Use either `_nftId` or `_name`. If you want to use `_name`, set `_nftId` to 0.
     */
    function toggleDelegation(uint256 _nftId, string memory _name) external;

    /**
     * @notice retrieveDelegation() your identity
     * @param _nftId The ID of the NFT.
     * @param _name The name of the identity.
     * @dev Use either `_nftId` or `_name`. If you want to use `_name`, set `_nftId` to 0.
     * @dev Only the identity origina; owner can call this and it shouldn't be during a delegation
     * @dev The system will automatically restore the original wallet receiver before transferring
     */
    function retrieveDelegation(uint256 _nftId, string memory _name) external;

    /**
     * updateDelegationWalletReceiver Update the wallet that will receive the token(s) from the delegation
     * @param _nftId The ID of the NFT.
     * @param _name The name of the identity.
     * @param _receiverWallet wallet you want the token(s) to be minted to
     * @dev Use either `_nftId` or `_name`. If you want to use `_name`, set `_nftId` to 0.
     * @dev only the delegatee can call this function. The term needs to be still active
     */
    function updateDelegationWalletReceiver(uint256 _nftId, string memory _name, address _receiverWallet) external;

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

    /**
     * @notice getDelegationData() Retrieves delegation data using the identity name.
     * @param _nftId The ID of the NFT.
     * @param _name The name of the identity.
     * @dev Use either `_nftId` or `_name`. If you want to use `_name`, set `_nftId` to 0.
     */
    function getDelegationData(uint256 _nftId, string calldata _name)
        external
        view
        returns (DelegatedIdentity memory);
}
