// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "../base/BaseTest.t.sol";
import { HelloWorld } from "src/HelloWorld.sol";

contract HelloWorldTest is BaseTest {
  address private owner = generateAddress("Owner", false);
  address private mockContract = generateAddress("ContractA", true);

  HelloWorld private underTest;

  function setUp() public {
    vm.setEnv("FOUNDRY_PROFILE", "unit");
    underTest = new HelloWorld(owner);
  }

  function test_constructor_thenContractWellConfigured() external {
    assertEq(underTest.owner(), owner);
  }

  function test_testMe_thenShouldReturn99e18() external {
    assertEq(underTest.testMe(), 99e18);
  }

  function test_ownerChangeValue_asNonOwner_thenReverts() public {
    vm.expectRevert("Not Owner");
    underTest.ownerChangeValue(399e18);
  }

  function test_ownerChangeValue_asOwner_thenReverts() public prankAs(owner) {
    underTest.ownerChangeValue(399e18);
    assertEq(underTest.value(), 399e18);
  }
}
