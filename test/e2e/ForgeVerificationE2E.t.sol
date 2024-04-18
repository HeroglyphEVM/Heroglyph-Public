// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "../base/BaseTest.t.sol";

contract ForgeVerificationE2E is BaseTest {
  function test_onRun_thenUsesE2EProfile() external {
    assertTrue(
      keccak256(abi.encode(vm.envString("FOUNDRY_PROFILE")))
        == keccak256(abi.encode("e2e"))
    );
  }
}
