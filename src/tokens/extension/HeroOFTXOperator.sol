// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { HeroOFTX, OApp } from "../HeroOFTX.sol";
import { IHeroOFTXOperator, IKey } from "./IHeroOFTXOperator.sol";
import { HeroOFTXCallbacksOperator } from "./HeroOFTXCallbacksOperator.sol";
import { TickerOperator } from "src/identity/ticker/operator/TickerOperator.sol";

import { MessagingFee, Origin } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title HeroOFTX
 * @notice Base OFT LZv2 with TickerOperation support
 */
abstract contract HeroOFTXOperator is IHeroOFTXOperator, HeroOFTXCallbacksOperator, HeroOFTX, TickerOperator {
    IKey public immutable key;

    address public wrappedNative;
    uint256 private latestBlockMinted;
    uint256 public totalMintedSupply;
    uint256 public maxSupply;
    address public treasury;
    uint32 public immutable localLzEndpointID;

    mapping(uint32 srcLzEndpoint => mapping(address => RequireAction[])) private requireActions;

    constructor(HeroOFTXOperatorArgs memory _heroArgs)
        TickerOperator(_heroArgs.owner, _heroArgs.heroglyphRelay, _heroArgs.feePayer)
        HeroOFTX(_heroArgs.lzGasLimit)
        OApp(_heroArgs.localLzEndpoint, _heroArgs.owner)
    {
        wrappedNative = _heroArgs.wrappedNative;
        key = IKey(_heroArgs.key);

        treasury = _heroArgs.treasury;
        maxSupply = _heroArgs.maxSupply;
        localLzEndpointID = _heroArgs.localLzEndpointID;
    }

    function onValidatorTriggered(
        uint32 _lzEndpointSelectionned,
        uint32 _blockMinted,
        address _validatorWithdrawer,
        uint128 /*_maxFee*/
    ) external override onlyRelay {
        //Avoid People from multi-tricker with a graffiti
        if (_blockMinted <= latestBlockMinted) return;
        if (address(key) != address(0) && key.balanceOf(_validatorWithdrawer) == 0) return;

        latestBlockMinted = _blockMinted;

        uint256 totalMinted;

        if (_lzEndpointSelectionned != localLzEndpointID) {
            totalMinted = _validatorCrosschain(_lzEndpointSelectionned, _validatorWithdrawer);
        } else {
            totalMinted = _onValidatorSameChain(_validatorWithdrawer);
        }

        totalMintedSupply += totalMinted;

        _repayHeroglyph();
    }

    function _validatorCrosschain(uint32 _lzDstEndpointId, address _to)
        internal
        virtual
        returns (uint256 totalMinted_)
    {
        (uint256 tokenIdOrAmount, uint256 totalMinted, bool success) = _onValidatorCrossChain(_to);
        if (!success) return 0;

        try this.validatorLZSend(_lzDstEndpointId, _to, tokenIdOrAmount) { }
        catch (bytes memory) {
            _onValidatorCrossChainFailed(_to, tokenIdOrAmount);
            emit OnCrossChainCallFails(_to, tokenIdOrAmount);
        }

        return totalMinted;
    }

    /**
     * @notice Allows for try-catch to prevent validators from missing their rewards due to fee/LZ issues.
     */
    function validatorLZSend(uint32 _lzDstEndpointId, address _to, uint256 _amount) external {
        if (msg.sender != address(this)) revert NoPermission();
        bytes memory options = defaultLzOption;
        uint64 shareChainValue = _toSharedDecimals(_amount);

        bytes memory payload = abi.encode(_to, shareChainValue, 1e18);
        MessagingFee memory fee = _quote(_lzDstEndpointId, payload, options, false);

        payload = abi.encode(_to, shareChainValue, fee.nativeFee);

        _askFeePayerToPay(address(this), fee.nativeFee);

        _lzSend(_lzDstEndpointId, payload, options, fee, payable(feePayer));
    }

    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address, /*_executor*/ // @dev unused in the default implementation.
        bytes calldata /*_extraData*/ // @dev unused in the default implementation.
    ) internal virtual override {
        (address to, uint64 idOrAmount, uint256 fee) = abi.decode(_message, (address, uint64, uint256));
        uint256 amountLD = _toLocalDecimals(idOrAmount);
        if (fee != 0) {
            requireActions[_origin.srcEid][to].push(RequireAction(amountLD, uint128(fee)));
        }

        uint256 amountReceivedLD = _credit(to, amountLD, fee > 0);
        emit OFTReceived(_guid, _origin.srcEid, to, amountReceivedLD);
    }

    function claimAction(uint32 _srcLzEndpoint, uint256[] calldata _indexes) external override {
        uint256 feeDue;
        for (uint256 i = 0; i < _indexes.length; i++) {
            feeDue += _executeAction(_srcLzEndpoint, msg.sender, _indexes[i]);
        }

        if (feeDue == 0) revert NoAction();

        if (!ERC20(wrappedNative).transferFrom(msg.sender, treasury, feeDue)) revert FailedToSendWETH();
    }

    function forgiveDebt(uint32 _srcLzEndpoint, address _of, uint256[] calldata _indexes) external override onlyOwner {
        uint256 feeDue;

        for (uint256 i = 0; i < _indexes.length; i++) {
            feeDue += _executeAction(_srcLzEndpoint, _of, _indexes[i]);
        }

        if (feeDue == 0) revert NoAction();
    }

    function _executeAction(uint32 _srcLzEndpoint, address _of, uint256 _index) internal returns (uint256 amountDue_) {
        RequireAction[] storage allActions = requireActions[_srcLzEndpoint][_of];
        uint256 totalActions = allActions.length;

        if (totalActions == 0 || _index > totalActions) return 0;
        totalActions -= 1;

        RequireAction storage action = allActions[_index];
        uint256 idOrAmount = action.amountOrId;
        amountDue_ = action.fee;

        if (totalActions != _index) {
            allActions[_index] = allActions[totalActions];
        }

        allActions.pop();

        _credit(_of, idOrAmount, false);

        return amountDue_;
    }

    function getActionsFeeTotal(uint32 _srcLzEndpoint, address _of, uint256[] calldata _indexes)
        external
        view
        returns (uint256 amountDue_)
    {
        RequireAction[] storage allActions = requireActions[_srcLzEndpoint][_of];
        uint256 totalActions = allActions.length;
        if (totalActions == 0) return 0;

        uint256 index;

        for (uint256 i = 0; i < _indexes.length; ++i) {
            index = _indexes[i];

            if (index >= totalActions) continue;
            amountDue_ += allActions[index].fee;
        }

        return amountDue_;
    }

    function _generateMessage(address _to, uint256 _amountOrId) internal view override returns (bytes memory) {
        return abi.encode(_to, _toSharedDecimals(_amountOrId), 0);
    }

    function _payNative(uint256 _nativeFee) internal override returns (uint256 nativeFee) {
        uint256 balance = address(this).balance;

        if (msg.value != 0 && msg.value < _nativeFee) revert NotEnoughNative(msg.value);
        if (msg.value == 0 && balance < _nativeFee) revert NotEnoughNative(balance);

        return _nativeFee;
    }

    function retrieveNative(address _to) external onlyOwner {
        (bool success,) = _to.call{ value: address(this).balance }("");
        if (!success) revert FailedToSendETH();
    }

    function updateTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    function updateNativeWrapper(address _wrapper) external onlyOwner {
        wrappedNative = _wrapper;
    }

    function getPendingActions(uint32 _lzEndpointID, address _user)
        external
        view
        override
        returns (RequireAction[] memory)
    {
        return requireActions[_lzEndpointID][_user];
    }

    function getLatestBlockMinted() external view override returns (uint256) {
        return latestBlockMinted;
    }

    function cap() external view returns (uint256) {
        return maxSupply;
    }

    receive() external payable { }
}
