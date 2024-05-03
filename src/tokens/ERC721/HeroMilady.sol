// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { OFT721 } from "./OFT721.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SendNativeHelper } from "./../../SendNativeHelper.sol";

/**
 * @title OFT721
 * @notice ERC721 + LZv2
 */
contract HeroMilady is OFT721, SendNativeHelper {
    error InvalidAmount();
    error CannotBeBoughtHere();
    error MaxSupplyReached();

    IERC20Metadata public immutable inputToken;
    address public immutable treasury;
    uint256 public immutable cost;
    string internal imageURI;
    bool public minted;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _imageURI,
        address _owner,
        address _localLzEndpoint,
        uint32 _lzGasLimit,
        uint256 _cost,
        address _treasury
    ) OFT721(_name, _symbol, "", _owner, _localLzEndpoint, _lzGasLimit) {
        if (_treasury == address(0)) revert("Treasury is Zero");

        inputToken = IERC20Metadata(address(0));
        treasury = _treasury;
        imageURI = _imageURI;
        cost = _cost;
    }

    function buy() external payable {
        if (cost == 0) revert CannotBeBoughtHere();
        if (msg.value != cost) revert InvalidAmount();
        if (minted) revert MaxSupplyReached();

        minted = true;
        _mint(msg.sender, 1);

        _sendNative(treasury, msg.value, true);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        string memory data = string(
            abi.encodePacked(
                '{"name":"', name(), '","description":"The one to rule them all.. Milady","image":"', imageURI, '"}'
            )
        );

        return string(abi.encodePacked("data:application/json;utf8,", data));
    }
}
