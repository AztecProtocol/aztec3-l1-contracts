// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {ERC20PresetFixedSupply} from "@oz/token/ERC20/presets/ERC20PresetFixedSupply.sol";

import {Rollup} from "../src/Rollup.sol";
import {Inbox} from "../src/messagebridge/Inbox.sol";
import {Outbox} from "../src/messagebridge/Outbox.sol";
import {MessageBox} from "../src/messagebridge/MessageBox.sol";

import {TokenPortal} from "../src/portals/TokenPortal.sol";
import {SplitPortal} from "../src/portals/SplitPortal.sol";
import {UniswapPortal} from "../src/portals/UniswapPortal.sol";

contract Messaging is Test {
  Rollup public rollup;
  Inbox public inbox;
  Outbox public outbox;

  ERC20PresetFixedSupply public asset1;
  ERC20PresetFixedSupply public asset2;

  TokenPortal public tokenPortal1;
  TokenPortal public tokenPortal2;
  SplitPortal public splitPortal;
  UniswapPortal public uniPortal;

  bytes32 public constant TOKEN_PORTAL_L2ADDRESS = bytes32("token_l2address_1");
  bytes32 public constant TOKEN_PORTAL2_L2ADDRESS = bytes32("token_l2address_2");
  bytes32 public constant SPLIT_PORTAL_L2ADDRESS = bytes32("split_l2address");
  bytes32 public constant UNI_PORTAL_L2ADDRESS = bytes32("uni_l2address");
  bytes32 public constant USER_L2ADDRESS = bytes32("alice");

  address public constant FEE_BENEFICIARY = address(0xf00b);

  function setUp() public {
    rollup = new Rollup();
    inbox = rollup.INBOX();
    outbox = rollup.OUTBOX();

    asset1 = ERC20PresetFixedSupply(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    asset2 = ERC20PresetFixedSupply(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    // Need a bit of weth
    deal(address(asset1), address(this), 100e18);

    tokenPortal1 = new TokenPortal(rollup, asset1);
    tokenPortal2 = new TokenPortal(rollup, asset2);
    splitPortal = new SplitPortal(rollup);

    uniPortal = new UniswapPortal(rollup);

    rollup.linkPortal(address(tokenPortal1), TOKEN_PORTAL_L2ADDRESS);
    rollup.linkPortal(address(tokenPortal2), TOKEN_PORTAL2_L2ADDRESS);
    rollup.linkPortal(address(splitPortal), SPLIT_PORTAL_L2ADDRESS);
    rollup.linkPortal(address(uniPortal), UNI_PORTAL_L2ADDRESS);

    vm.label(address(uniPortal.ROUTER()), "UniV3Router");
  }

  function testDepositIntoL2() public {
    uint256 depositAmount = 10e18;
    uint256 fee = 0;
    uint256 deadLine = type(uint256).max;
    bytes32 caller = bytes32(0);

    // User action, approve + deposit
    asset1.approve(address(tokenPortal1), depositAmount);
    bytes32 entryKey = tokenPortal1.deposit{value: fee}(
      depositAmount, USER_L2ADDRESS, caller, deadLine, address(this)
    );

    MessageBox.Entry memory entry = inbox.get(entryKey);
    assertEq(entry.count, 1);

    // We simulate a "process rollup" reading the message (and updating L2)
    // Pull this from `MessageAdded` event
    {
      bytes32[] memory l2Contracts = new bytes32[](1);
      uint256[] memory deadLines = new uint256[](1);
      uint256[] memory fees = new uint256[](1);
      bytes[] memory contents = new bytes[](1);

      l2Contracts[0] = TOKEN_PORTAL_L2ADDRESS;
      deadLines[0] = deadLine;
      fees[0] = fee;
      contents[0] = abi.encodeWithSignature(
        "deposit(uint256,bytes32,bytes32,address)",
        depositAmount,
        USER_L2ADDRESS,
        caller,
        address(this)
      );

      rollup.chugMessages(FEE_BENEFICIARY, l2Contracts, deadLines, fees, contents);

      assertFalse(inbox.contains(entryKey));
    }
  }

  function testWithdrawFromL2() public {
    // Perform initial deposit of 10e18 tokens
    testDepositIntoL2();

    // Simulate that we on L2 is performing a transaction to get funds out and rollup is processed
    uint256 withdrawAmount = 5e18;
    address recipient = address(0xf00);
    address caller = address(0);
    bytes memory content = abi.encodeWithSignature(
      "withdraw(uint256,address,address)", withdrawAmount, recipient, caller
    );
    bytes32 entryKey = outbox.computeEntryKey(address(tokenPortal1), content);

    {
      bytes32[] memory l2Contracts = new bytes32[](1);
      bytes[] memory contents = new bytes[](1);

      l2Contracts[0] = TOKEN_PORTAL_L2ADDRESS;
      contents[0] = content;

      rollup.messageDelivery(l2Contracts, contents);

      MessageBox.Entry memory entry = outbox.get(entryKey);
      assertEq(entry.count, 1);
    }

    emit log_named_decimal_uint("balance", asset1.balanceOf(recipient), 18);
    tokenPortal1.withdraw(withdrawAmount, recipient, false);
    emit log_named_decimal_uint("balance", asset1.balanceOf(recipient), 18);

    assertFalse(outbox.contains(entryKey));
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

    // Simulate something happening on L2, and being added to L1 outbox.
    bytes32[] memory entryKeys = new bytes32[](2);
    {
      bytes32[] memory l2Contracts = new bytes32[](2);
      bytes[] memory contents = new bytes[](2);
      // Prepare the money transfer
      {
        address recipient = address(splitPortal);
        address caller = address(splitPortal);
        contents[0] = abi.encodeWithSignature(
          "withdraw(uint256,address,address)", withdrawAmount, recipient, caller
        );
        l2Contracts[0] = TOKEN_PORTAL_L2ADDRESS;
        entryKeys[0] = outbox.computeEntryKey(address(tokenPortal1), contents[0]);
      }

      // Prepare the split execution message
      {
        contents[1] = abi.encodeWithSignature(
          "split(address,bytes32,bytes32,address)",
          address(tokenPortal1),
          keccak256(abi.encode(recipients)),
          keccak256(abi.encode(amounts)),
          address(0)
        );

        l2Contracts[1] = SPLIT_PORTAL_L2ADDRESS;
        entryKeys[1] = outbox.computeEntryKey(address(splitPortal), contents[1]);
      }

      assertFalse(outbox.contains(entryKeys[0]), "Key 0 already in outbox");
      assertFalse(outbox.contains(entryKeys[1]), "Key 1 already in outbox");

      // Nothing inserted here
      rollup.messageDelivery(l2Contracts, contents);

      assertTrue(outbox.contains(entryKeys[0]), "Key 0 not in outbox");
      assertTrue(outbox.contains(entryKeys[1]), "Key 1 not in outbox");
    }

    // Try to consume entry 0 without being the correct caller
    {
      // Compute the "bad" entry that we will lookup for "_withCaller = false"
      bytes32 badEntry = outbox.computeEntryKey(
        address(tokenPortal1),
        abi.encodeWithSignature(
          "withdraw(uint256,address,address)", withdrawAmount, address(splitPortal), address(0)
        )
      );
      vm.expectRevert(abi.encodeWithSelector(MessageBox.NothingToConsume.selector, badEntry));
      tokenPortal1.withdraw(withdrawAmount, address(splitPortal), false);

      // Compute the bad entry when being invalid caller for `_withCaller = true`
      badEntry = outbox.computeEntryKey(
        address(tokenPortal1),
        abi.encodeWithSignature(
          "withdraw(uint256,address,address)", withdrawAmount, address(splitPortal), address(this)
        )
      );
      vm.expectRevert(abi.encodeWithSelector(MessageBox.NothingToConsume.selector, badEntry));
      tokenPortal1.withdraw(withdrawAmount, address(splitPortal), true);
    }

    // Perform the full execution, where message 1 will execute message 0 as part of the flow
    {
      for (uint256 i = 0; i < 3; i++) {
        emit log_named_decimal_uint("balance", asset1.balanceOf(recipients[i]), 18);
      }

      splitPortal.split(address(tokenPortal1), recipients, amounts, false);

      for (uint256 i = 0; i < 3; i++) {
        emit log_named_decimal_uint("balance", asset1.balanceOf(recipients[i]), 18);
      }

      assertFalse(outbox.contains(entryKeys[0]));
      assertFalse(outbox.contains(entryKeys[1]));
    }
  }

  function testSwapFromL2() public {
    // Perform initial deposit of 10e18 tokens (such that we have funds in there)
    testDepositIntoL2();

    uint256 swapAmount = 5e18;

    // Simulate something happening on L2, and being added to L1 outbox.
    bytes32[] memory entryKeys = new bytes32[](2);
    {
      bytes32[] memory l2Contracts = new bytes32[](2);
      bytes[] memory contents = new bytes[](2);
      // Prepare the money transfer
      {
        address recipient = address(uniPortal);
        address caller = address(uniPortal);
        contents[0] = abi.encodeWithSignature(
          "withdraw(uint256,address,address)", swapAmount, recipient, caller
        );
        l2Contracts[0] = TOKEN_PORTAL_L2ADDRESS;
        entryKeys[0] = outbox.computeEntryKey(address(tokenPortal1), contents[0]);
      }

      // @todo: Use dai and weth as the assets so there will actually be a uniswap pool. Only annoying things is that we need a node then.

      // Prepare the swap execution message
      {
        contents[1] = abi.encodeWithSignature(
          "swap(address,uint256,uint24,address,bytes32,address,address)",
          address(tokenPortal1),
          swapAmount,
          500,
          address(tokenPortal2),
          USER_L2ADDRESS,
          address(0)
        );

        l2Contracts[1] = UNI_PORTAL_L2ADDRESS;
        entryKeys[1] = outbox.computeEntryKey(address(uniPortal), contents[1]);
      }

      assertFalse(outbox.contains(entryKeys[0]), "Key 0 already in outbox");
      assertFalse(outbox.contains(entryKeys[1]), "Key 1 already in outbox");

      // Nothing inserted here
      rollup.messageDelivery(l2Contracts, contents);

      assertTrue(outbox.contains(entryKeys[0]), "Key 0 not in outbox");
      assertTrue(outbox.contains(entryKeys[1]), "Key 1 not in outbox");
    }

    // Perform the full execution, where message 1 will execute message 0 as part of the flow
    {
      emit log_named_decimal_uint("balance 1", asset1.balanceOf(address(tokenPortal1)), 18);
      emit log_named_decimal_uint("balance 2", asset2.balanceOf(address(tokenPortal2)), 18);

      uniPortal.swap(
        address(tokenPortal1),
        swapAmount,
        500,
        address(tokenPortal2),
        USER_L2ADDRESS,
        address(this),
        false
      );

      emit log_named_decimal_uint("balance 1", asset1.balanceOf(address(tokenPortal1)), 18);
      emit log_named_decimal_uint("balance 2", asset2.balanceOf(address(tokenPortal2)), 18);

      assertFalse(outbox.contains(entryKeys[0]));
      assertFalse(outbox.contains(entryKeys[1]));
    }
  }
}
