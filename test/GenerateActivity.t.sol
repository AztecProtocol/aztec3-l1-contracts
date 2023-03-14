// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

import {Test} from "forge-std/Test.sol";

import {Rollup} from "@aztec3/core/Rollup.sol";
import {Yeeter} from "@aztec3/periphery/Yeeter.sol";

contract GenerateActivityTest is Test {
  Rollup internal constant ROLLUP = Rollup(0x01eF16c733AD450180232994c611bA4FADbb7e07);
  Yeeter internal constant YEETER = Yeeter(0x9BD4B3cF03Cfd4a07c6b0F1470518DAE4bBFa9AC);

  function _setUp() public {
    // check if there is no code at ROLLUP address
    if (address(ROLLUP).code.length == 0) {
      address rollup = deployRollupWithCreate2();
      assertEq(address(ROLLUP), rollup, "ROLLUP address mismatch");
    }
    if (address(YEETER).code.length == 0) {
      address yeeter = deployYeeterWithCreate2();
      assertEq(address(YEETER), yeeter, "YEETER address mismatch");
    }

    emit log_named_address("ROLLUP", address(ROLLUP));
    emit log_named_address("YEETER", address(YEETER));
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

  function deployRollupWithCreate2() public returns (address) {
    uint256 mySalt = 0xdeadbeef;
    bytes32 saltHash = keccak256(abi.encodePacked(mySalt));

    vm.broadcast();
    Rollup rollup = new Rollup{salt: saltHash}();
    return address(rollup);
  }

  function deployYeeterWithCreate2() public returns (address) {
    uint256 mySalt = 0xdeadbeef;
    bytes32 saltHash = keccak256(abi.encodePacked(mySalt));

    vm.broadcast();
    Yeeter yeeter = new Yeeter{salt: saltHash}();
    return address(yeeter);
  }
}
