// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ITicker } from "./ITicker.sol";
import { IdentityERC721 } from "./../IdentityERC721.sol";

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Ticker
 * @notice Tickers are contract identities; there is no real ownership on a ticker. It is possible to lose ownership
 * of it if your deposit reaches zero due to taxes or if it is hijacked by someone else.
 *
 * Tickers use the Harberger Tax logic with the following formula:
 * `tickerPrice * secondsSinceLastTimePaidTax / TAX_PERIOD`
 *
 * See ITicker.sol for more information
 */
contract Ticker is ITicker, IdentityERC721, ReentrancyGuard {
    using MessageHashUtils for bytes32;

    uint32 public constant TAX_PERIOD = 365 days;
    uint32 public initializationPeriod;
    uint32 public protectionInSeconds;

    mapping(uint256 => TickerMetadata) internal identities;

    constructor(address _owner, address _treasury, address _nameFilter, uint256 _cost)
        IdentityERC721(_owner, _treasury, _nameFilter, _cost, "Ticker", "Tkr")
    {
        protectionInSeconds = 7 days;
        initializationPeriod = uint32(block.timestamp + 1 hours);
    }

    function create(TickerCreation calldata _tickerCreation) external payable override {
        if (initializationPeriod > block.timestamp) revert InitializationPeriodActive();
        _executeCreate(_tickerCreation, 0);
    }

    function createWithImmune(TickerCreation calldata _tickerCreation, uint32 _immunityDuration)
        external
        payable
        onlyOwner
    {
        _executeCreate(_tickerCreation, _immunityDuration);
    }

    function _executeCreate(TickerCreation calldata _tickerCreation, uint32 _immunityDuration) private {
        string memory tickerName = _tickerCreation.name;
        uint128 price = _tickerCreation.setPrice;

        if (price < cost) revert PriceTooLow();
        if (msg.value < cost) revert NotEnough();

        uint256 id = _create(tickerName, 0);

        identities[id] = TickerMetadata({
            name: tickerName,
            contractTarget: _tickerCreation.contractTarget,
            owningDate: uint32(block.timestamp),
            lastTimeTaxPaid: uint32(block.timestamp + _immunityDuration),
            immunityEnds: uint32(block.timestamp + _immunityDuration),
            price: price,
            deposit: uint128(msg.value)
        });
    }

    function hijack(uint256 _nftId, string memory _name, uint128 _tickerPrice, uint128 _newPrice)
        external
        payable
        override
    {
        (_nftId, _name) = _sanitizeIdAndName(_nftId, _name);

        TickerMetadata storage ticker = identities[_nftId];

        _payTax(_nftId, ticker);

        address currentOwner = ownerOf(_nftId);
        uint128 price = ticker.price;

        if (price > _tickerPrice) revert FrontRunGuard();
        if (_newPrice < cost) revert PriceTooLow();

        if (currentOwner == address(0)) revert TickerNotFound();
        if (currentOwner == msg.sender) revert CantSelfBuy();
        if (currentOwner != address(this) && block.timestamp < ticker.owningDate + protectionInSeconds) {
            revert ProtectionStillActive();
        }
        if (block.timestamp < ticker.immunityEnds) revert TickerIsImmune();
        if (msg.value < price) revert NotEnough();

        uint128 totalOwned = price + ticker.deposit;
        ticker.deposit = uint128(msg.value) - price;
        _transferTicker(_nftId, ownerOf(_nftId), msg.sender, _newPrice);

        _sendNative(currentOwner, totalOwned, false);

        emit TickerHijacked(_nftId, _name, msg.sender, price, totalOwned);
    }

    function updateTicker(uint256 _nftId, string memory _name, address _contractTarget) external override {
        (_nftId, _name) = _sanitizeIdAndName(_nftId, _name);

        TickerMetadata storage ticker = identities[_nftId];

        if (ownerOf(_nftId) != msg.sender) revert NotIdentityOwner();

        if (!_payTax(_nftId, ticker)) revert TickerUnderWater();

        ticker.contractTarget = _contractTarget;
        emit TickerUpdated(_nftId, _name, _contractTarget, ticker.price);
    }

    function updatePrice(uint256 _nftId, string memory _name, uint128 _newPrice) external override {
        (_nftId, _name) = _sanitizeIdAndName(_nftId, _name);

        TickerMetadata storage ticker = identities[_nftId];

        if (ownerOf(_nftId) != msg.sender) revert NotIdentityOwner();
        if (_newPrice < cost) revert PriceTooLow();

        if (!_payTax(_nftId, ticker)) revert TickerUnderWater();
        ticker.price = _newPrice;

        emit TickerUpdated(_nftId, _name, ticker.contractTarget, _newPrice);
    }

    function increaseDeposit(uint256 _nftId, string memory _name) external payable override {
        (_nftId, _name) = _sanitizeIdAndName(_nftId, _name);

        if (ownerOf(_nftId) != msg.sender) revert NotIdentityOwner();

        TickerMetadata storage ticker = identities[_nftId];
        ticker.deposit += uint128(msg.value);

        if (!_payTax(_nftId, ticker)) revert TickerUnderWater();

        emit AddedDepositToTicker(_nftId, _name, ticker.deposit, uint128(msg.value));
    }

    function withdrawDeposit(uint256 _nftId, string memory _name, uint128 _amount) external override nonReentrant {
        (_nftId, _name) = _sanitizeIdAndName(_nftId, _name);

        TickerMetadata storage ticker = identities[_nftId];

        if (ownerOf(_nftId) != msg.sender) revert NotIdentityOwner();

        _payTax(_nftId, ticker);
        uint128 deposit = ticker.deposit;

        if (_amount == 0) _amount = deposit;
        if (_amount > deposit || deposit == 0) revert NotEnough();

        deposit -= _amount;
        ticker.deposit = deposit;

        _trySurrender(_nftId, deposit);
        _sendNative(msg.sender, _amount, true);

        emit WithdrawnFromTicker(_nftId, _name, ticker.deposit, _amount);
    }

    function _payTax(uint256 _tickerId, TickerMetadata storage _ticker) internal returns (bool success_) {
        if (_tickerId == 0) revert NotIdentityOwner();
        if (_ticker.price == 0) return true;

        success_ = true;

        uint128 currentPrice = _ticker.price;
        uint128 deposit = _ticker.deposit;
        uint32 lastTimeTaxPaid = _ticker.lastTimeTaxPaid;
        uint32 lastTimeTaxPaidWithBalance = uint32(block.timestamp);

        uint256 tax = _getTaxDue(currentPrice, lastTimeTaxPaid);

        if (tax == 0) return success_;

        if (tax >= deposit) {
            success_ = false;

            lastTimeTaxPaidWithBalance =
                lastTimeTaxPaid + uint32(Math.mulDiv(block.timestamp - lastTimeTaxPaid, deposit, tax));

            tax = deposit;
        } else {
            _ticker.lastTimeTaxPaid = uint32(block.timestamp);
        }

        deposit -= uint128(tax);
        _ticker.deposit = deposit;

        emit TaxPaid(_tickerId, _ticker.name, tax, deposit, lastTimeTaxPaidWithBalance);

        _trySurrender(_tickerId, deposit);
        _sendNative(treasury, tax, true);

        return success_;
    }

    function _trySurrender(uint256 _id, uint128 _deposit) internal {
        if (_deposit != 0) return;

        _transferTicker(_id, ownerOf(_id), address(this), 0);
    }

    function _transferTicker(uint256 _id, address _owner, address _newOwner, uint128 _newPrice) internal {
        if (_id == 0) revert NotIdentityOwner();

        TickerMetadata storage ticker = identities[_id];

        ticker.price = _newPrice;
        ticker.lastTimeTaxPaid = uint32(block.timestamp);
        ticker.owningDate = uint32(block.timestamp);

        address previousOwner = _update(_newOwner, _id, address(0));
        if (previousOwner != _owner) revert NotIdentityOwner();

        if (_newPrice == 0) {
            emit TickerSurrendered(_id, ticker.name, _owner);
        }
    }

    function _sanitizeIdAndName(uint256 _id, string memory _name) internal view returns (uint256, string memory) {
        if (_id == 0) {
            _id = identityIds[_name];
        } else {
            _name = identities[_id].name;
        }

        return (_id, _name);
    }

    function transferFrom(address, address, uint256) public pure override {
        revert("Non-Transferrable");
    }

    function updateProtectionTime(uint32 _seconds) external onlyOwner {
        if (_seconds < 60) revert ProtectionMinimumOneMinute();

        protectionInSeconds = _seconds;
        emit ProtectionTimeUpdated(_seconds);
    }

    function getDeposit(uint256 _nftId, string calldata _name) external view override returns (uint256) {
        if (_nftId == 0) {
            _nftId = identityIds[_name];
        }

        return identities[_nftId].deposit;
    }

    function getDepositLeft(uint256 _nftId, string calldata _name) external view override returns (uint256 _left) {
        if (_nftId == 0) {
            _nftId = identityIds[_name];
        }

        TickerMetadata memory ticker = identities[_nftId];
        uint256 due = _getTaxDue(ticker.price, ticker.lastTimeTaxPaid);

        if (due >= ticker.deposit) return 0;

        return ticker.deposit - due;
    }

    function getTaxDue(uint256 _nftId, string calldata _name) external view override returns (uint256 _tax) {
        if (_nftId == 0) {
            _nftId = identityIds[_name];
        }

        TickerMetadata memory ticker = identities[_nftId];
        return _getTaxDue(ticker.price, ticker.lastTimeTaxPaid);
    }

    function _getTaxDue(uint128 _price, uint128 _lastPaid) private view returns (uint256 _tax) {
        if (_lastPaid >= block.timestamp) return 0;

        return Math.mulDiv(_price, (block.timestamp - _lastPaid), TAX_PERIOD);
    }

    function getTickerMetadata(uint256 _nftId, string calldata _name)
        external
        view
        override
        returns (TickerMetadata memory ticker_, bool shouldBeSurrender_)
    {
        if (_nftId == 0) {
            _nftId = identityIds[_name];
        }

        ticker_ = identities[_nftId];
        shouldBeSurrender_ = (ticker_.deposit <= _getTaxDue(ticker_.price, ticker_.lastTimeTaxPaid));

        return (ticker_, shouldBeSurrender_);
    }
}
