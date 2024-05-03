// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

interface IHeroOFTX {
    event OFTSent(bytes32 indexed guid, uint32 indexed destinationEndpointId, address indexed to, uint256 amountOrId);
    event OFTReceived(bytes32 indexed guid, uint32 indexed sourceEndpointId, address indexed to, uint256 amountOrId);

    /**
     * @notice Estimate Cross-chain fee
     * @param _dstEid Destination LZ Endpoint ID
     * @param _to Receiver of the asset
     * @param _tokenIdOrAmount NFT ID or Amount of the Token sending
     */
    function estimateFee(uint32 _dstEid, address _to, uint256 _tokenIdOrAmount) external view returns (uint256);
}
