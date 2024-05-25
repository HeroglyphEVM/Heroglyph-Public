// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ValidatorIdentityV2 } from "./v2/ValidatorIdentityV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IDelegation } from "./delegation/IDelegation.sol";
import { IIdentityRouter } from "./IIdentityRouter.sol";

contract IdentityRouter is Ownable, IIdentityRouter {
    mapping(string identityName => mapping(uint32 => RouterConfig)) internal routers;

    ValidatorIdentityV2 public validatorIdentity;
    IDelegation public delegation;

    constructor(address _owner, address _validatorIdentityV2) Ownable(_owner) {
        validatorIdentity = ValidatorIdentityV2(_validatorIdentityV2);
    }

    /**
     * @inheritdoc IIdentityRouter
     */
    function hookIdentities(string calldata _parentIdentiyName, string[] calldata _children) external override {
        if (_children.length == 0) revert EmptyArray();
        if (validatorIdentity.ownerOf(_parentIdentiyName) != msg.sender) revert NotIdentityOwner();

        ValidatorIdentityV2.Identifier memory identity;
        string memory childIdentityName;

        for (uint256 i = 0; i < _children.length; ++i) {
            childIdentityName = _children[i];
            identity = validatorIdentity.getIdentityData(0, childIdentityName);

            if (bytes(identity.name).length == 0) revert ChildNotFound(i, childIdentityName);

            routers[_parentIdentiyName][identity.validatorUUID] = RouterConfig(childIdentityName, false);

            emit HookedIdentity(_parentIdentiyName, identity.validatorUUID, childIdentityName);
        }
    }

    /**
     * @inheritdoc IIdentityRouter
     */
    function toggleUseChildWalletReceiver(string calldata _parentIdentiyName, uint32 _validatorId) external override {
        if (validatorIdentity.ownerOf(_parentIdentiyName) != msg.sender) revert NotIdentityOwner();

        RouterConfig storage routerConfig = routers[_parentIdentiyName][_validatorId];
        bool newStatus = !routerConfig.useChildWallet;

        routerConfig.useChildWallet = newStatus;

        emit UseChildWalletUpdated(_parentIdentiyName, _validatorId, routerConfig.childName, newStatus);
    }

    /**
     * @inheritdoc IIdentityRouter
     */
    function getWalletReceiver(string calldata _parentIdentiyName, uint32 _validatorId)
        external
        view
        override
        returns (address walletReceiver_, bool isDelegated_)
    {
        if (address(delegation) != address(0) && delegation.isDelegated(_parentIdentiyName, _validatorId)) {
            return (address(delegation), true);
        }

        RouterConfig memory routerConfig = routers[_parentIdentiyName][_validatorId];
        bool isRouted = keccak256(abi.encode(routerConfig.childName)) != keccak256(abi.encode(""));

        string memory idName = isRouted && routerConfig.useChildWallet ? routerConfig.childName : _parentIdentiyName;
        ValidatorIdentityV2.Identifier memory identityData = validatorIdentity.getIdentityData(0, idName);

        walletReceiver_ =
            (isRouted || identityData.validatorUUID == _validatorId) ? identityData.walletReceiver : address(0);

        return (walletReceiver_, false);
    }

    function updateValidatorIdentity(address _validatorIdentity) external onlyOwner {
        validatorIdentity = ValidatorIdentityV2(_validatorIdentity);
        emit ValidatorIdentityUpdated(_validatorIdentity);
    }

    function updateDelegation(address _delegation) external onlyOwner {
        delegation = IDelegation(_delegation);
        emit DelegationUpdated(_delegation);
    }

    /**
     * @inheritdoc IIdentityRouter
     */
    function getRouterConfig(string calldata _parentIdentityName, uint32 _validatorId)
        external
        view
        returns (RouterConfig memory)
    {
        return routers[_parentIdentityName][_validatorId];
    }
}
