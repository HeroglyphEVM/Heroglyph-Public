// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IdentityERC721 } from "../IdentityERC721.sol";
import { IValidatorIdentity } from "./IValidatorIdentity.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title ValidatorIdentity
 * @notice Validators require an identity to link the wallet where they wish to receive rewards (if applicable).
 * Unlike the Ticker, ValidatorIdentity is permanently owned by its creator and contains no tax.
 *
 * For more details, refer to IValidatorIdentity.sol.
 */
contract ValidatorIdentity is IValidatorIdentity, IdentityERC721 {
    using MessageHashUtils for bytes32;

    mapping(uint256 => DelegatedIdentity) internal delegations;
    Identifier[] internal identities;
    uint32 public earlyBridsEnd;
    bytes32 public EARLY_BIRD_ROOT;

    modifier onlyEndEarlyBirdsPeriod() {
        if (earlyBridsEnd > block.timestamp) revert EarlyBirdOnly();
        _;
    }

    constructor(address _owner, address _treasury, address _nameFilter, uint256 _cost)
        IdentityERC721(_owner, _treasury, _nameFilter, _cost, "ValidatorIdentity", "EthI")
    {
        identities.push(Identifier({ name: "DEAD_WALLET", tokenReceiver: address(0) }));
        earlyBridsEnd = uint32(block.timestamp + 1 weeks);

        EARLY_BIRD_ROOT = 0x62fbdf096d8fd9adb08eda13e6f821e6e0da674a69c02a5cf718f17cffea12ac;
    }

    function createWhitelisted(string calldata _name, address _receiverWallet, bytes32[] calldata proofs)
        external
        payable
    {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender))));
        if (!MerkleProof.verify(proofs, EARLY_BIRD_ROOT, leaf)) revert InvalidProof();

        _executeCreate(_name, _receiverWallet);
    }

    function createWithSignature(
        string calldata _name,
        address _receiverWallet,
        uint256 _deadline,
        bytes memory _signature
    ) external payable override onlyEndEarlyBirdsPeriod {
        if (block.timestamp >= _deadline) revert ExpiredSignature();

        bytes32 ethSignature = keccak256(abi.encodePacked(msg.sender, _name, _deadline)).toEthSignedMessageHash();
        address signer = ECDSA.recover(ethSignature, _signature);

        if (signer != msg.sender) revert NotSigner();

        _executeCreate(_name, _receiverWallet);
    }

    function create(string calldata _name, address _receiverWallet) external payable override onlyEndEarlyBirdsPeriod {
        _executeCreate(_name, _receiverWallet);
    }

    function _executeCreate(string memory _name, address _receiverWallet) internal {
        _create(_name, cost);
        identities.push(
            Identifier({ name: _name, tokenReceiver: _receiverWallet == address(0) ? msg.sender : _receiverWallet })
        );
    }

    function delegate(uint256 _nftId, string memory _name, uint128 _delegateCost, uint8 _amountOfMonths)
        external
        override
    {
        if (_amountOfMonths == 0) revert InvalidMonthTime();

        if (_nftId == 0) {
            _nftId = identityIds[_name];
        } else {
            _name = identities[_nftId].name;
        }

        delegations[_nftId] = DelegatedIdentity({
            isEnabled: true,
            owner: msg.sender,
            originalTokenReceiver: identities[_nftId].tokenReceiver,
            delegatee: address(0),
            durationInMonths: _amountOfMonths,
            endDelegationTime: 0,
            cost: _delegateCost
        });

        _transfer(msg.sender, address(this), _nftId);

        emit DelegationUpdated(_name, _nftId, true);
    }

    function acceptDelegation(uint256 _nftId, string memory _name, address _receiverWallet) external payable override {
        if (_nftId == 0) {
            _nftId = identityIds[_name];
        } else {
            _name = identities[_nftId].name;
        }

        DelegatedIdentity storage delegated = delegations[_nftId];

        if (!delegated.isEnabled) revert DelegationNotActive();
        if (delegated.endDelegationTime > block.timestamp) revert DelegationNotOver();
        if (delegated.cost != msg.value) revert NotEnough();

        uint32 endPeriod = uint32(block.timestamp + (30 days * uint32(delegated.durationInMonths)));

        delegated.delegatee = msg.sender;
        delegated.endDelegationTime = endPeriod;

        _updateReceiverAddress(_nftId, _receiverWallet);

        _sendNative(delegated.owner, msg.value, true);

        emit IdentityDelegated(_name, _nftId, msg.sender, endPeriod);
    }

    function toggleDelegation(uint256 _nftId, string memory _name) external override {
        if (_nftId == 0) {
            _nftId = identityIds[_name];
        } else {
            _name = identities[_nftId].name;
        }

        DelegatedIdentity storage delegated = delegations[_nftId];
        bool currentState = delegated.isEnabled;

        if (delegated.owner != msg.sender) revert NotIdentityOwner();

        delegated.isEnabled = !currentState;

        emit DelegationUpdated(_name, _nftId, !currentState);
    }

    function retrieveDelegation(uint256 _nftId, string memory _name) external override {
        if (_nftId == 0) {
            _nftId = identityIds[_name];
        } else {
            _name = identities[_nftId].name;
        }

        DelegatedIdentity storage delegated = delegations[_nftId];

        if (delegated.owner != msg.sender) revert NotIdentityOwner();
        if (delegated.endDelegationTime > block.timestamp) revert DelegationNotOver();

        if (delegated.isEnabled) {
            emit DelegationUpdated(_name, _nftId, false);
        }

        _updateReceiverAddress(_nftId, delegated.originalTokenReceiver);

        delete delegations[_nftId];

        _transfer(address(this), msg.sender, _nftId);
    }

    function updateDelegationWalletReceiver(uint256 _nftId, string memory _name, address _receiverWallet)
        external
        override
    {
        if (_nftId == 0) {
            _nftId = identityIds[_name];
        } else {
            _name = identities[_nftId].name;
        }

        DelegatedIdentity storage delegated = delegations[_nftId];

        if (delegated.delegatee != msg.sender) revert NotDelegatee();
        if (delegated.endDelegationTime <= block.timestamp) revert DelegationOver();

        _updateReceiverAddress(_nftId, _receiverWallet);
    }

    function updateReceiverAddress(uint256 _nftId, string memory _name, address _receiver) external override {
        if (_nftId == 0) {
            _nftId = identityIds[_name];
        } else {
            _name = identities[_nftId].name;
        }

        if (ownerOf(_nftId) != msg.sender) revert NotIdentityOwner();

        _updateReceiverAddress(_nftId, _receiver);
    }

    function _updateReceiverAddress(uint256 _nftId, address _receiver) private {
        Identifier storage identity = identities[_nftId];
        identity.tokenReceiver = _receiver;

        emit TokenReceiverUpdated(_nftId, identity.name, _receiver);
    }

    function updateEarlyBirdRoot(bytes32 _root) external onlyOwner {
        EARLY_BIRD_ROOT = _root;
    }

    function getIdentityData(uint256 _nftId, string calldata _name)
        external
        view
        override
        returns (Identifier memory)
    {
        if (_nftId == 0) {
            _nftId = identityIds[_name];
        }

        return identities[_nftId];
    }

    function getDelegationData(uint256 _nftId, string calldata _name)
        external
        view
        override
        returns (DelegatedIdentity memory)
    {
        if (_nftId == 0) {
            _nftId = identityIds[_name];
        }

        return delegations[_nftId];
    }
}
