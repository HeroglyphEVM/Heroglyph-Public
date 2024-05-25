// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

interface IIdentityRouter {
    error NotIdentityOwner();
    error ChildNotFound(uint256 indexPosition, string childName);
    error EmptyArray();

    event HookedIdentity(string indexed parentIdentityName, uint32 indexed childValidatorIndex, string childName);
    event ValidatorIdentityUpdated(address validatorIdentity);
    event DelegationUpdated(address delegation);
    event UseChildWalletUpdated(
        string indexed parentIdentityName, uint32 indexed childValidatorIndex, string childName, bool useChildWallet
    );

    struct RouterConfig {
        string childName;
        bool useChildWallet;
    }

    /**
     * hookIdentities Hooks multiple identities to a parent identity.
     * @param _parentIdentiyName Parent identity name
     * @param _children Child identity names
     * @dev The reward will be sent to the Parent identity's wallet receiver.
     */
    function hookIdentities(string calldata _parentIdentiyName, string[] calldata _children) external;

    /**
     * toggleUseChildWalletReceiver Toggles the use of the child wallet receiver.
     * @param _parentIdentiyName Parent identity name
     * @param _validatorId Validator ID
     */
    function toggleUseChildWalletReceiver(string calldata _parentIdentiyName, uint32 _validatorId) external;

    /**
     * getWalletReceiver Returns the wallet receiver address for a given parent identity and validator id.
     * @param _parentIdentiyName Parent identity name
     * @param _validatorId Validator id
     * @return walletReceiver_ Wallet receiver address. Returns empty address if not routed or soulbound.
     * @return isDelegated_ True if the identity is delegated.
     */
    function getWalletReceiver(string calldata _parentIdentiyName, uint32 _validatorId)
        external
        view
        returns (address walletReceiver_, bool isDelegated_);

    /**
     * getRouterConfig Returns the router configuration for a given parent identity and validator id.
     * @param _parentIdentityName Parent identity name
     * @param _validatorId Validator id
     * @return RouterConfig_ Router configuration tuple(string childName, boolean useChildWallet)
     */
    function getRouterConfig(string calldata _parentIdentityName, uint32 _validatorId)
        external
        view
        returns (RouterConfig memory);
}
