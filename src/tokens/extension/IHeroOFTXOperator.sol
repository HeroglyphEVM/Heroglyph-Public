// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IKey
 * @author A key is most-likely an NFT, but it can be whatever that support balanceOf
 */
interface IKey {
    function balanceOf(address account) external view returns (uint256);
}

interface IHeroOFTXOperator {
    error NoAction();
    error NoPermission();
    error FailedToSendWETH();

    event TreasuryUpdated(address indexed treasury);

    struct RequireAction {
        uint256 amountOrId;
        uint128 fee;
    }

    struct HeroOFTXOperatorArgs {
        address wrappedNative;
        address key;
        address owner;
        address treasury;
        address feePayer;
        address heroglyphRelay;
        address localLzEndpoint;
        uint32 localLzEndpointID;
        uint32 lzGasLimit;
        uint256 maxSupply;
    }

    event OnCrossChainCallFails(address indexed validator, uint256 amountOrNftId);

    /**
     * @notice claimAction() When a validator sets a cross-chain in graffiti, they have to pay the LZ fee. The asset is
     * frozen and is waiting for the user's action
     * @param _srcLzEndpoint Origin Lz endpoint ID of the asset
     * @param _indexes Array of action indexes to execute in batch
     */
    function claimAction(uint32 _srcLzEndpoint, uint256[] calldata _indexes) external;

    /**
     * @notice forgiveDebt() The owner of the contract can forgive the debt of a user and execute the pending actions on
     * their behalf.
     * @param _srcLzEndpoint Origin Lz endpoint ID of the asset
     * @param _of Address of the user
     * @param _indexes Array of action indexes to execute in batch
     */
    function forgiveDebt(uint32 _srcLzEndpoint, address _of, uint256[] calldata _indexes) external;

    /**
     * @notice getPendingActions() Retrieves all pending actions of an address.
     * @param _lzEndpointID Origin LZ Endpoint ID.
     * @param _user Address of the user.
     * @return actions Array of Action tuples (uint256 amountOrId, uint128 fee).
     */
    function getPendingActions(uint32 _lzEndpointID, address _user) external view returns (RequireAction[] memory);

    /**
     * @notice getLatestBlockMinted() Retrieves the latest executed block.
     */
    function getLatestBlockMinted() external view returns (uint256);
}
