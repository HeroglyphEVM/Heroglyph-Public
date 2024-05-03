// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IGasPool } from "./identity/ticker/operator/ITickerOperator.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SendNativeHelper } from "./SendNativeHelper.sol";

contract ExecutionPool is IGasPool, Ownable, SendNativeHelper {
    error NoPermission();

    event AccessUpdated(address indexed who, bool isEnable);
    event Paid(address indexed caller, address indexed to, uint256 amount);

    mapping(address => bool) private accesses;

    modifier onlyAccess() {
        if (!accesses[msg.sender]) revert NoPermission();

        _;
    }

    constructor(address _owner) Ownable(_owner) { }

    function payTo(address _to, uint256 _amount) external onlyAccess {
        _sendNative(_to, _amount, true);

        emit Paid(msg.sender, _to, _amount);
    }

    function setAccessTo(address _to, bool _enable) external onlyOwner {
        accesses[_to] = _enable;

        emit AccessUpdated(_to, _enable);
    }

    function hasAccess(address _who) external view returns (bool) {
        return accesses[_who];
    }

    function retrieveNative(address _to) external onlyOwner {
        _sendNative(_to, address(this).balance, true);
    }

    receive() external payable { }
}
