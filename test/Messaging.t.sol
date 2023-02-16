// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {ERC20PresetFixedSupply} from "@oz/token/ERC20/presets/ERC20PresetFixedSupply.sol";

import {Rollup} from "../src/Rollup.sol";
import {Inbox} from "../src/messagebridge/Inbox.sol";
import {Outbox} from "../src/messagebridge/Outbox.sol";

import {TokenPortal} from "../src/portals/TokenPortal.sol";
import {SplitPortal} from "../src/portals/SplitPortal.sol";

contract Messaging is Test {
  Rollup public rollup;
  Inbox public inbox;
  Outbox public outbox;

  ERC20PresetFixedSupply public asset;

  TokenPortal public tokenPortal;
  SplitPortal public splitPortal;

  bytes32 public constant TOKEN_PORTAL_L2ADDRESS = bytes32("token_l2address");
  bytes32 public constant SPLIT_PORTAL_L2ADDRESS = bytes32("split_l2address");
  bytes32 public constant USER_L2ADDRESS = bytes32("alice");

  function setUp() public {
    rollup = new Rollup();
    inbox = rollup.INBOX();
    outbox = rollup.OUTBOX();

    asset = new ERC20PresetFixedSupply(
            "asset",
            "asset",
            100e18,
            address(this)
        );

    tokenPortal = new TokenPortal(rollup, asset);
    splitPortal = new SplitPortal(rollup);

    rollup.linkPortal(address(tokenPortal), TOKEN_PORTAL_L2ADDRESS);
    rollup.linkPortal(address(splitPortal), SPLIT_PORTAL_L2ADDRESS);
  }

  function testDepositIntoL2() public {
    uint256 depositAmount = 10e18;

    // User action, approve + depost
    asset.approve(address(tokenPortal), depositAmount);
    tokenPortal.deposit(depositAmount, USER_L2ADDRESS);

    // We check that something was inserted into the inbox
    bytes memory content = abi.encode(depositAmount, USER_L2ADDRESS);
    bytes32 messageHash = sha256(content);
    bytes32 inboxEntryHash = keccak256(abi.encode(address(tokenPortal), block.chainid, messageHash));

    assertEq(inbox.entries(0), inboxEntryHash);
    assertEq(inbox.messageCount(), 1);
    assertEq(inbox.consumeCount(), 0);

    // We simulate a "process rollup" reading the message (and updating L2)
    {
      bytes32[] memory l2Contracts = new bytes32[](1);
      bytes32[] memory msgHashes = new bytes32[](1);

      l2Contracts[0] = TOKEN_PORTAL_L2ADDRESS;
      msgHashes[0] = messageHash;

      // Consume just 1 message
      rollup.chugMessages(l2Contracts, msgHashes, 1);

      assertEq(inbox.messageCount(), 1);
      assertEq(inbox.consumeCount(), 1);
    }
  }

  function testWithdrawFromL2() public {
    // Perform initial deposit of 10e18 tokens
    testDepositIntoL2();

    // Simulate that we on L2 is performing a transaction to get funds out and rollup is processed
    uint256 withdrawAmount = 5e18;
    address recipient = address(0xf00);
    bytes memory content = abi.encode(withdrawAmount, recipient);
    bytes32 msgHash = sha256(content);

    {
      bytes32[] memory l2Contracts = new bytes32[](1);
      address[] memory callers = new address[](1);
      bytes32[] memory msgHashes = new bytes32[](1);

      l2Contracts[0] = TOKEN_PORTAL_L2ADDRESS;
      msgHashes[0] = msgHash;

      rollup.messageDelivery(l2Contracts, callers, msgHashes);

      Outbox.OutboxEntry memory entry = outbox.getEntry(address(tokenPortal), msgHash);
      assertEq(entry.caller, address(0));
      assertTrue(entry.exists);
    }

    emit log_named_decimal_uint("balance", asset.balanceOf(recipient), 18);

    tokenPortal.withdraw(withdrawAmount, recipient);

    emit log_named_decimal_uint("balance", asset.balanceOf(recipient), 18);

    Outbox.OutboxEntry memory entry = outbox.getEntry(address(tokenPortal), msgHash);
    assertEq(entry.caller, address(0));
    assertFalse(entry.exists);
  }

  function testSplitWithdrawFromL2() public {
    // Perform initial deposit of 10e18 tokens
    testDepositIntoL2();

    address[] memory recipients = new address[](3);
    uint256[] memory amounts = new uint256[](3);

    recipients[0] = address(1);
    recipients[1] = address(2);
    recipients[2] = address(3);

    amounts[0] = 3e18;
    amounts[1] = 1.5e18;
    amounts[2] = 0.5e18;

    uint256 withdrawAmount = 5e18;

    bytes32[] memory msgHashes = new bytes32[](2);

    {
      bytes32[] memory l2Contracts = new bytes32[](2);
      address[] memory callers = new address[](2);
      // Prepare the money transfer
      {
        bytes memory content = abi.encode(withdrawAmount, address(splitPortal));
        bytes32 msgHash = sha256(content);
        l2Contracts[0] = TOKEN_PORTAL_L2ADDRESS;
        callers[0] = address(splitPortal);
        msgHashes[0] = msgHash;
      }

      // Prepare the split execution message
      {
        bytes memory content = abi.encode(address(tokenPortal), recipients, amounts);
        bytes32 msgHash = sha256(content);
        l2Contracts[1] = SPLIT_PORTAL_L2ADDRESS;
        msgHashes[1] = msgHash;
      }

      rollup.messageDelivery(l2Contracts, callers, msgHashes);

      Outbox.OutboxEntry memory entry0 = outbox.getEntry(address(tokenPortal), msgHashes[0]);
      assertEq(entry0.caller, address(splitPortal));
      assertTrue(entry0.exists);

      Outbox.OutboxEntry memory entry1 = outbox.getEntry(address(splitPortal), msgHashes[1]);
      assertEq(entry1.caller, address(0));
      assertTrue(entry1.exists);
    }

    // Try to consume entry 0 without being the correct caller
    {
      vm.expectRevert(abi.encodeWithSelector(Outbox.CallerRequired.selector, address(splitPortal)));
      tokenPortal.withdraw(withdrawAmount, address(splitPortal));
    }

    // Perform the full execution, where message 1 will execute message 0 as part of the flow
    {
      for (uint256 i = 0; i < 3; i++) {
        emit log_named_decimal_uint("balance", asset.balanceOf(recipients[i]), 18);
      }

      splitPortal.split(address(tokenPortal), recipients, amounts);

      for (uint256 i = 0; i < 3; i++) {
        emit log_named_decimal_uint("balance", asset.balanceOf(recipients[i]), 18);
      }

      Outbox.OutboxEntry memory entry0 = outbox.getEntry(address(tokenPortal), msgHashes[0]);
      assertEq(entry0.caller, address(0));
      assertFalse(entry0.exists);

      Outbox.OutboxEntry memory entry1 = outbox.getEntry(address(splitPortal), msgHashes[1]);
      assertEq(entry1.caller, address(0));
      assertFalse(entry1.exists);
    }
  }
}
