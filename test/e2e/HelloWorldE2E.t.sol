// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "../base/BaseTest.t.sol";
import { HelloWorld } from "src/HelloWorld.sol";

contract ForkTest is BaseTest {
  string private MAINNET_RPC;
  string private ARBITRUM_RPC;

  uint256 mainnetFork;
  uint256 arbitrumFork;

  function setUp() public {
    MAINNET_RPC = vm.envString("RPC_MAINNET");
    ARBITRUM_RPC = vm.envString("RPC_ARBITRUM");

    mainnetFork = vm.createFork(MAINNET_RPC);
    arbitrumFork = vm.createFork(ARBITRUM_RPC);
  }

  function testForkIdDiffer() public view {
    assert(mainnetFork != arbitrumFork);
  }

  function testCanSelectFork() public {
    vm.selectFork(mainnetFork);
    assertEq(vm.activeFork(), mainnetFork);
  }

  function testCanSwitchForks() public {
    vm.selectFork(mainnetFork);
    assertEq(vm.activeFork(), mainnetFork);

    vm.selectFork(arbitrumFork);
    assertEq(vm.activeFork(), arbitrumFork);
  }

  function testCanCreateAndSelectForkInOneStep() public {
    uint256 anotherFork = vm.createSelectFork(MAINNET_RPC);
    assertEq(vm.activeFork(), anotherFork);
  }

  function testCanSetForkBlockNumber() public {
    vm.selectFork(mainnetFork);
    vm.rollFork(1_337_000);

    assertEq(block.number, 1_337_000);
  }
}
