// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import { MockERC20ABI } from "../mock/abi/MockERC20ABI.t.sol";

contract BaseTest is Test, MockERC20ABI {
  uint256 internal constant MAX_UINT = type(uint256).max;
  address internal constant ZERO_ADDRESS = address(0);

  uint256 private seed;

  /**
   * Start Pranking as a specific address
   */
  modifier prankAs(address caller) {
    vm.startPrank(caller, caller);
    _;
    vm.stopPrank();
  }

  /**
   * Start Pranking, you don't care who.
   * Mainly used when you have multiple pranks and want to use
   * changePrank();
   */
  modifier pranking() {
    vm.startPrank(address(0x1671629561), address(0x1671629561));
    _;
    vm.stopPrank();
  }

  function changePrank(address msgSender) internal override {
    vm.stopPrank();
    vm.startPrank(msgSender, msg.sender);
  }

  function generateAddress() internal returns (address) {
    return generateAddress("Quick Generated Address", false, 0);
  }

  function generateAddress(uint256 _balance) internal returns (address) {
    return generateAddress("Quick Generated Address", false, _balance);
  }

  function generateAddress(string memory _name) internal returns (address) {
    return generateAddress(_name, false, 0);
  }

  function generateAddress(string memory _name, uint256 _balance)
    internal
    returns (address)
  {
    return generateAddress(_name, false, _balance);
  }

  function generateAddress(string memory _name, bool _isContract)
    internal
    returns (address)
  {
    return generateAddress(_name, _isContract, 0);
  }

  function generateAddress(string memory _name, bool _isContract, uint256 _ethBalance)
    internal
    returns (address newAddress_)
  {
    seed++;
    newAddress_ = vm.addr(seed);

    vm.label(newAddress_, _name);

    if (_isContract) {
      vm.etch(newAddress_, "Generated Contract Address");
    }

    vm.deal(newAddress_, _ethBalance);

    return newAddress_;
  }

  function assertEqTolerance(
    uint256 a,
    uint256 b,
    uint256 tolerancePercentage //4 decimals
  ) internal {
    uint256 diff = b > a ? b - a : a - b;
    uint256 maxForgivness = (b * tolerancePercentage) / 100_000;

    if (maxForgivness < diff) {
      emit log("Error: a == b not satisfied [with tolerance]");
      emit log_named_uint("  A", a);
      emit log_named_uint("  B", b);
      emit log_named_uint("  Max tolerance", maxForgivness);
      emit log_named_uint("    Actual Difference", diff);
      fail();
    }
  }

  function expectExactEmit() internal {
    vm.expectEmit(true, true, true, true);
  }
}
