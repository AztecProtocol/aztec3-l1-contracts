// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

import {Rolodex} from "./messagebridge/Rolodex.sol";
import {Inbox} from "./messagebridge/Inbox.sol";
import {Outbox} from "./messagebridge/Outbox.sol";

contract Rollup {
  error InvalidFormat();
  error InvalidEntry();

  event ChuggedMessages(uint256 chugged, uint256 totalChugged);

  Rolodex public immutable ROLODEX;
  Inbox public immutable INBOX;
  Outbox public immutable OUTBOX;

  constructor() {
    Rolodex rolodex = new Rolodex();
    ROLODEX = rolodex;
    INBOX = new Inbox(rolodex);
    OUTBOX = new Outbox();
  }

  /// Helper functions, that should be called by processing rollup
  /// But callable directly because it makes testing much easier

  function linkPortal(address _portal, bytes32 _l2Address) public returns (bool) {
    return ROLODEX.addLink(_portal, _l2Address);
  }

  // Note: Using l2Addresses for the things interacting directly with the rollup as this seemed like something that could make the interacting easier as rollup circuit should not deal to much with the L1 addresses, the contract does that for it.

  /**
   * @notice Reads pending messages from Inbox and put them into the rollup
   * Takes partial entries as input, and computes the remaining on L1.
   * This function should be executed as part of the process rollup
   * @dev Reverts if input is badly formatted
   * @dev Reverts if computed entry don't match consumed entry
   * @param _l2Addresses - The list of l2 addresses to receive messages
   * @param _msgHashes - The hashes of the message content
   * @param _consumeCount - The number of messages from Inbox to consume
   */
  function chugMessages(
    bytes32[] memory _l2Addresses,
    bytes32[] memory _msgHashes,
    uint256 _consumeCount
  ) public {
    if (_msgHashes.length != _consumeCount) revert InvalidFormat();
    if (_l2Addresses.length != _consumeCount) revert InvalidFormat();

    (uint256 totalConsumed, bytes32[] memory consumed) = INBOX.chug(_consumeCount);
    if (consumed.length != _consumeCount) revert InvalidFormat();

    // Check that every consumed entry matches input
    for (uint256 i = 0; i < _consumeCount; i++) {
      address portalAddress = ROLODEX.portals(_l2Addresses[i]);
      bytes32 entryHash = keccak256(abi.encode(portalAddress, block.chainid, _msgHashes[i]));
      if (entryHash != consumed[i]) revert InvalidEntry();
    }

    emit ChuggedMessages(_consumeCount, totalConsumed);
  }

  /**
   * @notice Takes messages received from L2, and puts them into the outbox on L1
   * To be executed as part of the process rollup -> Validation except finding portal address performed inside proof
   */
  function messageDelivery(
    bytes32[] memory _l2Addresses,
    address[] memory _callers,
    bytes32[] memory _msgHashes
  ) public {
    address[] memory portals = new address[](_l2Addresses.length);
    for (uint256 i = 0; i < portals.length; i++) {
      portals[i] = ROLODEX.portals(_l2Addresses[i]);
      // TODO: Consider if we want to check here. Only address(0) can consume,
      // so might be fine to ignore. Then we don't have issues with sequencer
      // being forced to include things without knowing it they are bad etc
      // easier for us to battle censoring as they would be non-consumable messages
      if (portals[i] == address(0)) revert InvalidEntry();
    }
    OUTBOX.receiveMessages(portals, _callers, _msgHashes);
  }
}
