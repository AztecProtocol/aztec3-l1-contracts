// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

import {Test} from "forge-std/Test.sol";

import {Rollup} from "@aztec3/core/Rollup.sol";
import {Yeeter} from "@aztec3/periphery/Yeeter.sol";

// 1. run: `anvil`
// 2. run: `forge script --fork-url "http://127.0.0.1:8545/" --ffi GenerateActivityTest --sig "testGenerateActivity()" --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast`
contract GenerateActivityTest is Test {
  Rollup internal constant ROLLUP = Rollup(0x5FbDB2315678afecb367f032d93F642f64180aa3);
  Yeeter internal constant YEETER = Yeeter(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);

  function _setUp() public {
    // check if there is no code at ROLLUP address
    if (address(ROLLUP).code.length == 0) {
      vm.broadcast();
      address rollup = address(new Rollup());
      assertEq(address(ROLLUP), rollup, "ROLLUP address mismatch");
      emit log_named_address("Deployed Rollup to", address(ROLLUP));
    }
    if (address(YEETER).code.length == 0) {
      vm.broadcast();
      address yeeter = address(new Yeeter());
      assertEq(address(YEETER), yeeter, "YEETER address mismatch");
      emit log_named_address("Deployed Yeeter to", address(YEETER));
    }
  }

  function testGenerateActivity() public {
    _setUp();
    emit log_uint(ROLLUP.latestBlockNum());
    for (uint256 i = 0; i < 5; i++) {
      vm.startBroadcast();
      ROLLUP.processRollup();
      YEETER.yeet(ROLLUP.latestBlockNum(), bytes(""));
      vm.stopBroadcast();
      emit log_named_uint("Settled block", ROLLUP.latestBlockNum());
    }
  }
}
