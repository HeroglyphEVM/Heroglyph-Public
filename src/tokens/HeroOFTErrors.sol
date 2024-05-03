// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface HeroOFTErrors {
    error GasLimitCannotBeZero();
    error SlippageExceeded(uint256 amountLD, uint256 minAmountLD);
    error ConversionOutOfBounds();
}
