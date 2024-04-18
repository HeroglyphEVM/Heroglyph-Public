// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "../base/BaseTest.t.sol";

contract ForgeVerification is BaseTest {
  function test_onRun_thenUsesUnitProfile() external {
    assertTrue(
      keccak256(abi.encode(vm.envString("FOUNDRY_PROFILE")))
        == keccak256(abi.encode("unit"))
    );
  }
}
