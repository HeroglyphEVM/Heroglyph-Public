// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { OFT20Ticker, ERC20 } from "./../../tokens/ERC20/OFT20Ticker.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract HeroLinearToken20 is OFT20Ticker {
    error NoRedeemTokenDectected();
    error RewardLowerThanMinimumAllowed();
    error NoRewardCurrently();
    error RedeemDecayTooHigh();
    error NoKeyDectected();
    error NotRedeemHub();

    event TokenRedeemed(address indexed from, uint256 reward);

    uint32 public constant DECAY_BPS = 500;
    uint32 public constant DECAY_RESTART = 53 hours;

    ERC20 public immutable redeemToken;
    address public immutable redeemHub;
    uint256 public immutable tokenPerSecond;
    uint256 public extraRewardForMiner;
    uint32 public lastMintTriggered;

    uint32 public lastRedeemCall;
    uint32 public totalReedemCalls;

    constructor(
        string memory _name,
        string memory _symbol,
        address _feeCollector,
        uint32 _crossChainFee,
        uint256 _preMintAmount,
        address _preMintTo,
        uint256 _tokenPerSecond,
        address _redeemToken,
        address _redeemHub,
        HeroOFTXOperatorArgs memory _heroArgs
    ) OFT20Ticker(_name, _symbol, _feeCollector, _crossChainFee, _heroArgs) {
        tokenPerSecond = _tokenPerSecond;
        lastMintTriggered = uint32(block.timestamp);
        redeemToken = ERC20(_redeemToken);
        redeemHub = _redeemHub;

        if (_preMintAmount == 0 || _preMintTo == address(0)) return;

        _mint(_preMintTo, _preMintAmount);
        totalMintedSupply += _preMintAmount;
    }

    function _onValidatorSameChain(address _to) internal override returns (uint256) {
        return _executeMint(_to, true);
    }

    function _onValidatorCrossChain(address)
        internal
        override
        returns (uint256 tokenIdOrAmount_, uint256 totalMinted_, bool success_)
    {
        tokenIdOrAmount_ = _executeMint(address(0), true);
        return (tokenIdOrAmount_, tokenIdOrAmount_, tokenIdOrAmount_ != 0);
    }

    function redeem(uint256 _minReward) external returns (uint256 rewardMinted_) {
        rewardMinted_ = _redeem(msg.sender, _minReward);
        redeemToken.transferFrom(msg.sender, address(this), 1e18);

        return rewardMinted_;
    }

    function redeemFromHub(address _to, uint256 _minReward) external returns (uint256 rewardMinted_) {
        if (msg.sender != redeemHub) revert NotRedeemHub();
        return _redeem(_to, _minReward);
    }

    function _redeem(address _caller, uint256 _minReward) internal returns (uint256 rewardMinted_) {
        if (address(redeemToken) == address(0)) revert NoRedeemTokenDectected();
        if (address(key) != address(0) && key.balanceOf(_caller) == 0) revert NoKeyDectected();

        rewardMinted_ = _executeMint(address(0), false);

        if (lastRedeemCall + DECAY_RESTART <= block.timestamp) {
            totalReedemCalls = 0;
        }

        uint32 penaltyBSP = DECAY_BPS * totalReedemCalls;

        totalReedemCalls++;
        lastRedeemCall = uint32(block.timestamp);

        if (penaltyBSP >= 10_000) revert RedeemDecayTooHigh();

        uint256 penaltyReward = Math.mulDiv(rewardMinted_, penaltyBSP, 10_000);

        extraRewardForMiner += penaltyReward;
        rewardMinted_ -= penaltyReward;

        if (rewardMinted_ == 0) revert NoRewardCurrently();
        if (_minReward != 0 && rewardMinted_ < _minReward) revert RewardLowerThanMinimumAllowed();

        totalMintedSupply += rewardMinted_;
        _mint(_caller, rewardMinted_);

        emit TokenRedeemed(_caller, rewardMinted_);

        return rewardMinted_;
    }

    function _executeMint(address _to, bool _isMining) internal returns (uint256 reward_) {
        reward_ = _calculateTokensToEmit(uint32(block.timestamp));
        lastMintTriggered = uint32(block.timestamp);

        if (_isMining) {
            reward_ += extraRewardForMiner;
            extraRewardForMiner = 0;
        }

        if (_to != address(0)) _mint(_to, reward_);

        return reward_;
    }

    function getNextReward() external view returns (uint256) {
        return _calculateTokensToEmit(uint32(block.timestamp));
    }

    function getRedeemPenaltyBPS() external view returns (uint32) {
        uint32 cachedTotalCalls = totalReedemCalls;
        if (lastRedeemCall + DECAY_RESTART <= block.timestamp) {
            cachedTotalCalls = 0;
        }

        return DECAY_BPS * cachedTotalCalls;
    }

    function _calculateTokensToEmit(uint32 _timestamp) private view returns (uint256) {
        uint32 difference = _timestamp - lastMintTriggered;
        uint256 minting = difference * tokenPerSecond;
        uint256 totalMintedSupplyCached = totalMintedSupply;
        uint256 maxSupplyCached = maxSupply;

        if (minting == 0 || maxSupplyCached == 0) return minting;
        if (totalMintedSupplyCached >= maxSupplyCached) return 0;
        if (totalMintedSupplyCached + minting <= maxSupplyCached) return minting;

        return maxSupplyCached - totalMintedSupplyCached;
    }
}
