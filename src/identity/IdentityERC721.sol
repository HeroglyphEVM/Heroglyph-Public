// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IIdentityERC721 } from "./IIdentityERC721.sol";
import { SendNativeHelper } from "./../SendNativeHelper.sol";

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { NameFilter } from "./NameFilter.sol";

/**
 * @title IdentityERC721
 * @notice The base of Ticker & ValidatorIdentity. It handles name verification, id tracking and the payment
 */
abstract contract IdentityERC721 is IIdentityERC721, ERC721, SendNativeHelper, Ownable {
    address public treasury;
    uint256 public cost;
    NameFilter public nameFilter;

    mapping(string => uint256) internal identityIds;
    uint256 private nextIdToMint;

    /**
     * @dev Important, id starts at 1. When creating an Identity, call _create to validate and mint
     */
    constructor(
        address _owner,
        address _treasury,
        address _nameFilter,
        uint256 _cost,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) Ownable(_owner) {
        if (_treasury == address(0)) revert TreasuryNotSet();

        nameFilter = NameFilter(_nameFilter);
        nextIdToMint = 1;
        treasury = _treasury;
        cost = _cost;
    }

    function _create(string memory _name, uint256 _expectingCost) internal returns (uint256 mintedId_) {
        if (_expectingCost != 0 && msg.value != _expectingCost) revert ValueIsNotEqualsToCost();
        if (identityIds[_name] != 0) revert NameAlreadyTaken();

        (bool isNameHealthy, uint256 characterIndex) = nameFilter.isNameValidWithIndexError(_name);
        if (!isNameHealthy) revert InvalidCharacter(characterIndex);

        mintedId_ = nextIdToMint;
        ++nextIdToMint;

        identityIds[_name] = mintedId_;

        _safeMint(msg.sender, mintedId_);
        emit NewIdentityCreated(mintedId_, _name, msg.sender);

        if (_expectingCost == 0) return mintedId_;

        _sendNative(treasury, msg.value, true);

        return mintedId_;
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        if (tokenId == 0) revert InvalidIdZero();
        return super._update(to, tokenId, auth);
    }

    function isNameAvailable(string calldata _name) external view returns (bool success_, int32 failedAt_) {
        return _isNameAvailable(_name);
    }

    function _isNameAvailable(string calldata _name) internal view virtual returns (bool success_, int32 failedAt_) {
        if (identityIds[_name] != 0) return (false, -1);

        uint256 characterIndex;
        (success_, characterIndex) = nameFilter.isNameValidWithIndexError(_name);

        return (success_, int32(uint32(characterIndex)));
    }

    function getIdentityNFTId(string calldata _name) external view override returns (uint256) {
        return identityIds[_name];
    }

    function ownerOf(string calldata _name) external view returns (address) {
        return ownerOf(identityIds[_name]);
    }

    function updateNameFilter(address _newFilter) external onlyOwner {
        nameFilter = NameFilter(_newFilter);
        emit NameFilterUpdated(_newFilter);
    }

    function updateCost(uint256 _cost) external onlyOwner {
        cost = _cost;
        emit CostUpdated(_cost);
    }

    function updateTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }
}
