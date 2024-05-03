// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { HeroLinearToken20, ERC20 } from "./tokens/ERC20/HeroLinearToken20.sol";

contract RedeemHub {
    event RedeemToken(address indexed caller, address indexed token, uint256 reward);

    ERC20 public immutable attestationToken;

    constructor(address _attestationToken) {
        attestationToken = ERC20(_attestationToken);
    }

    function redeem(address _token, uint256 _minRedeemAmount) external {
        attestationToken.transferFrom(msg.sender, _token, 1e18);
        uint256 reward = HeroLinearToken20(payable(_token)).redeemFromHub(msg.sender, _minRedeemAmount);

        emit RedeemToken(msg.sender, _token, reward);
    }
}
