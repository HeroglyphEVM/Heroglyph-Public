// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { HeroOFTX, OApp } from "./../HeroOFTX.sol";

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title OFT721
 * @notice ERC721 + LZv2
 */
abstract contract OFT721 is HeroOFTX, ERC721, IERC721Receiver {
    error NFTOwnerIsNotContract();

    string internal contractURIJsonUTF8;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _contractURI,
        address _owner,
        address _localLzEndpoint,
        uint32 _lzGasLimit
    ) ERC721(_name, _symbol) HeroOFTX(_lzGasLimit) OApp(_localLzEndpoint, _owner) Ownable(_owner) {
        contractURIJsonUTF8 = _contractURI;
    }

    function contractURI() public view returns (string memory) {
        return contractURIJsonUTF8;
    }

    function _baseURI() internal view override returns (string memory) {
        return contractURI();
    }

    function _debit(uint256 _amountOrId, uint256) internal override returns (uint256 _amountSendingOrId_) {
        _transfer(msg.sender, address(this), _amountOrId);

        return _amountOrId;
    }

    function _credit(address _to, uint256 _value, bool) internal override returns (uint256) {
        bool exists = _exists(_value);

        if (exists && _ownerOf(_value) != address(this)) revert NFTOwnerIsNotContract();

        if (!exists) {
            _safeMint(_to, _value);
        } else {
            _transfer(address(this), _to, _value);
        }

        return _value;
    }

    function _exists(uint256 _tokenId) internal view returns (bool) {
        return _ownerOf(_tokenId) != address(0);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
