// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IdentityERC721 } from "../../IdentityERC721.sol";
import { IValidatorIdentityV2 } from "./IValidatorIdentityV2.sol";
import { IValidatorIdentity } from "../IValidatorIdentity.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title ValidatorIdentityV2
 * @notice Validators require an identity to link the wallet where they wish to receive rewards (if applicable).
 * Unlike the Ticker, ValidatorIdentity is permanently owned by its creator and contains no tax.
 *
 * For more details, refer to IValidatorIdentity.sol.
 */
contract ValidatorIdentityV2 is IValidatorIdentityV2, IdentityERC721 {
    uint256 public constant MAX_BPS = 10_000;

    IValidatorIdentity public immutable oldIdentity;
    mapping(uint256 => Identifier) internal identities;

    uint32 public resetCounterTimestamp;
    uint32 public boughtToday;
    uint32 public maxIdentityPerDayAtInitialPrice;
    uint32 public priceIncreaseThreshold;
    uint32 public priceDecayBPS;
    uint256 public currentPrice;

    constructor(address _owner, address _treasury, address _nameFilter, uint256 _cost, address _oldIdentity)
        IdentityERC721(_owner, _treasury, _nameFilter, _cost, "ValidatorIdentity", "EthI")
    {
        oldIdentity = IValidatorIdentity(_oldIdentity);
        resetCounterTimestamp = uint32(block.timestamp + 1 days);
        currentPrice = cost;
        maxIdentityPerDayAtInitialPrice = 25;
        priceIncreaseThreshold = 10;
        priceDecayBPS = 2500;
    }

    function isSoulboundIdentity(string calldata _name, uint32 _validatorId) external view override returns (bool) {
        uint256 nftId = identityIds[_name];
        return identities[nftId].validatorUUID == _validatorId;
    }

    function migrateFromOldIdentity(string calldata _name, uint32 _validatorId) external override {
        if (address(oldIdentity) == address(0)) revert NoMigrationPossible();

        // Happens if the user created an new identity on the old version while the name was already taken in this
        // version
        if (identityIds[_name] != 0) revert NotBackwardCompatible();

        IValidatorIdentity.DelegatedIdentity memory oldDelegation = oldIdentity.getDelegationData(0, _name);
        IValidatorIdentity.Identifier memory oldIdentityData = oldIdentity.getIdentityData(0, _name);

        bool isDelegatedAndOwner = oldDelegation.isEnabled && oldDelegation.owner == msg.sender;
        bool isOwner = IdentityERC721(address(oldIdentity)).ownerOf(_name) == msg.sender;

        if (!isDelegatedAndOwner && !isOwner) revert NotIdentityOwner();

        _createIdentity(_name, oldIdentityData.tokenReceiver, _validatorId, 0);
    }

    function create(string calldata _name, address _receiverWallet, uint32 _validatorId) external payable override {
        if (cost == 0 && msg.value != 0) revert NoNeedToPay();

        _executeCreate(_name, _receiverWallet, _validatorId);
    }

    function _executeCreate(string calldata _name, address _receiverWallet, uint32 _validatorId) internal {
        if (_isNameExistingFromOldVersion(_name)) revert NameAlreadyTaken();

        uint256 costAtDuringTx = _updateCost();

        if (msg.value < costAtDuringTx) revert MsgValueTooLow();

        _sendNative(treasury, costAtDuringTx, true);
        _sendNative(msg.sender, msg.value - costAtDuringTx, true);

        _createIdentity(_name, _receiverWallet, _validatorId, costAtDuringTx);
    }

    function _createIdentity(string calldata _name, address _receiverWallet, uint32 _validatorId, uint256 _cost)
        internal
    {
        if (_receiverWallet == address(0)) _receiverWallet = msg.sender;

        uint256 id = _create(_name, 0);
        identities[id] = Identifier({ name: _name, validatorUUID: _validatorId, walletReceiver: _receiverWallet });

        emit NewGraffitiIdentityCreated(id, _validatorId, _name, _cost);
        emit WalletReceiverUpdated(id, _name, _receiverWallet);
    }

    function _updateCost() internal returns (uint256 userCost_) {
        (resetCounterTimestamp, boughtToday, currentPrice, userCost_) = _getCostDetails();
        return userCost_;
    }

    function getCost() external view returns (uint256 userCost_) {
        (,,, userCost_) = _getCostDetails();
        return userCost_;
    }

    function _getCostDetails()
        internal
        view
        returns (
            uint32 resetCounterTimestampReturn_,
            uint32 boughtTodayReturn_,
            uint256 currentCostReturn_,
            uint256 userCost_
        )
    {
        uint32 maxPerDayCached = maxIdentityPerDayAtInitialPrice;
        resetCounterTimestampReturn_ = resetCounterTimestamp;
        boughtTodayReturn_ = boughtToday;
        currentCostReturn_ = currentPrice;

        if (block.timestamp >= resetCounterTimestampReturn_) {
            uint256 totalDayPassed = (block.timestamp - resetCounterTimestampReturn_) / 1 days + 1;
            resetCounterTimestampReturn_ += uint32(1 days * totalDayPassed);
            boughtTodayReturn_ = 0;

            for (uint256 i = 0; i < totalDayPassed; ++i) {
                currentCostReturn_ =
                    Math.max(cost, currentCostReturn_ - Math.mulDiv(currentCostReturn_, priceDecayBPS, MAX_BPS));

                if (currentCostReturn_ <= cost) break;
            }
        }

        bool boughtExceedsMaxPerDay = boughtTodayReturn_ > maxPerDayCached;

        if (boughtExceedsMaxPerDay && (boughtTodayReturn_ - maxPerDayCached) % priceIncreaseThreshold == 0) {
            currentCostReturn_ += cost / 2;
        }

        userCost_ = !boughtExceedsMaxPerDay ? cost : currentCostReturn_;
        boughtTodayReturn_++;

        return (resetCounterTimestampReturn_, boughtTodayReturn_, currentCostReturn_, userCost_);
    }

    function updateReceiverAddress(uint256 _nftId, string calldata _name, address _receiver) external override {
        if (_nftId == 0) {
            _nftId = identityIds[_name];
        }

        if (ownerOf(_nftId) != msg.sender) revert NotIdentityOwner();

        Identifier storage identity = identities[_nftId];
        identity.walletReceiver = _receiver;

        emit WalletReceiverUpdated(_nftId, identity.name, _receiver);
    }

    function updateMaxIdentityPerDayAtInitialPrice(uint32 _maxIdentityPerDayAtInitialPrice) external onlyOwner {
        maxIdentityPerDayAtInitialPrice = _maxIdentityPerDayAtInitialPrice;
        emit MaxIdentityPerDayAtInitialPriceUpdated(_maxIdentityPerDayAtInitialPrice);
    }

    function updatePriceIncreaseThreshold(uint32 _priceIncreaseThreshold) external onlyOwner {
        priceIncreaseThreshold = _priceIncreaseThreshold;
        emit PriceIncreaseThresholdUpdated(_priceIncreaseThreshold);
    }

    function updatePriceDecayBPS(uint32 _priceDecayBPS) external onlyOwner {
        if (_priceDecayBPS > MAX_BPS) revert InvalidBPS();
        priceDecayBPS = _priceDecayBPS;
        emit PriceDecayBPSUpdated(_priceDecayBPS);
    }

    function transferFrom(address, address, uint256) public pure override {
        revert("Non-Transferrable");
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

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        Identifier memory identity = identities[tokenId];

        string memory data = string(
            abi.encodePacked(
                '{"name":"Graffiti Identity @',
                identity.name,
                '","description":"Required for your Heroglyph Graffiti","image":"',
                "ipfs://QmdTq1vZ6cZ6mcJBfkG49FocwqTPFQ8duq6j2tL2rpzEWF",
                '"}'
            )
        );

        return string(abi.encodePacked("data:application/json;utf8,", data));
    }

    function _isNameAvailable(string calldata _name) internal view override returns (bool success_, int32 failedAt_) {
        if (_isNameExistingFromOldVersion(_name)) return (false, -1);

        return super._isNameAvailable(_name);
    }

    function _isNameExistingFromOldVersion(string calldata _name) internal view returns (bool) {
        return address(oldIdentity) != address(0) && IdentityERC721(address(oldIdentity)).getIdentityNFTId(_name) != 0;
    }
}
