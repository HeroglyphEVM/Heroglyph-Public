// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { HeroOFTXOperator, IHeroOFTXOperator } from "../extension/HeroOFTXOperator.sol";

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title OFT721Ticker
 * @notice Mixed of ERC721 + LZ OFTv2 + Ticker Operation
 */
contract OFT721Ticker is HeroOFTXOperator, ERC721, IERC721Receiver {
    error NFTOwnerIsNotContract();

    string public baseURI;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        IHeroOFTXOperator.HeroOFTXOperatorArgs memory _heroArgs
    ) ERC721(_name, _symbol) HeroOFTXOperator(_heroArgs) {
        baseURI = _uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _onValidatorSameChain(address _to) internal override returns (uint256 totalMinted_) {
        return _mintAndTrack(_to) != 0 ? 1 : 0;
    }

    function _onValidatorCrossChain(address /*_to*/ )
        internal
        override
        returns (uint256 tokenId_, uint256 totalMinted_, bool success_)
    {
        tokenId_ = _mintAndTrack(address(this));
        success_ = tokenId_ != 0;

        return (tokenId_, success_ ? 1 : 0, success_);
    }

    function _onValidatorCrossChainFailed(address _to, uint256 _nftId) internal override {
        _transfer(address(this), _to, _nftId);
    }

    function _mintAndTrack(address _to) internal virtual returns (uint256 tokenId_) {
        uint256 maxSupplyCached = maxSupply;
        uint256 totalMintedCached = totalMintedSupply;

        if (maxSupplyCached != 0 && totalMintedCached >= maxSupplyCached) return 0;

        tokenId_ = totalMintedCached + 1;
        _safeMint(_to, tokenId_);

        return tokenId_;
    }

    function _debit(uint256 _amountOrId, uint256) internal override returns (uint256 _amountSendingOrId_) {
        _transfer(msg.sender, address(this), _amountOrId);

        return _amountOrId;
    }

    function _credit(address _to, uint256 _value, bool _isFrozen) internal override returns (uint256) {
        if (_isFrozen) return _value;

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
