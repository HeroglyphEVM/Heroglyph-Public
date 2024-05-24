// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

interface IIdentityERC721 {
    error NameAlreadyTaken();
    error InvalidCharacter(uint256 characterIndex);
    error ValueIsNotEqualsToCost();
    error TreasuryNotSet();
    error NotIdentityOwner();
    error InvalidIdZero();

    event NewIdentityCreated(uint256 indexed identityId, string indexed identityName, address indexed owner);
    event NameFilterUpdated(address indexed newNameFilter);
    event CostUpdated(uint256 newCost);
    event TreasuryUpdated(address newTreasury);

    /**
     * @notice getIdentityNFTId get the NFT Id attached to the name
     * @param _name Identity Name
     * @return nftId
     * @dev ID: 0 == DEAD_NFT
     */
    function getIdentityNFTId(string calldata _name) external view returns (uint256);

    /**
     * @notice ownerOf getOwner of the NFT with the Identity Name
     * @param _name Name of the Identity
     */
    function ownerOf(string calldata _name) external view returns (address);
}
