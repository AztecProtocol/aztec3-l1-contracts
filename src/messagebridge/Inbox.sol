// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

import {Rolodex} from "./Rolodex.sol";

/**
 * @title Inbox
 * @author LHerskind
 * @notice Used to pass messages into the rollup, e.g., L1 -> L2 messages.
 * Message are stored in a id => msgHash mapping as we can easily enforce insert ordering,
 * and that way to ensure a sequencers cannot "skip" inserted messages.
 */
contract Inbox {
  error Unauthorized();
  error NotPortal(address caller);

  event MessageSent(
    address indexed portal, bytes32 indexed recipient, bytes32 msgHash, bytes content
  );

  Rolodex immutable ROLODEX;
  address immutable ROLLUP;

  // inboxEntry = keccak256(address portal, block.chainid, sha256(messageData))
  mapping(uint256 index => bytes32 inboxEntry) public entries;
  uint256 public messageCount;
  uint256 public consumeCount;

  /**
   * @notice Deploys t
   * @param _rolodex - The address of the Rolodex, which keeps track of contracts.
   */
  constructor(Rolodex _rolodex) {
    ROLLUP = msg.sender;
    ROLODEX = _rolodex;
  }

  /**
   * @notice Inserts a message into the message box
   * @dev Only callable if the caller is a portal contract according to the Rolodex
   * @param _content The message content (application specific)
   * @return The index of the entry in entries "array"
   */
  function sendL2Message(bytes memory _content) external returns (uint256) {
    bytes32 l2Address = ROLODEX.l2Contracts(msg.sender);
    if (l2Address == bytes32(0)) {
      revert NotPortal(msg.sender);
    }

    bytes32 messageHash = sha256(_content);
    bytes32 entryHash = keccak256(abi.encode(msg.sender, block.chainid, messageHash));

    uint256 messageId = messageCount;

    entries[messageId] = entryHash;
    messageCount += 1;

    emit MessageSent(msg.sender, l2Address, entryHash, _content);

    return messageId;
  }

  /**
   * @notice Consumes up to _toConsumeCount messages (less if not enough messages to consume)
   * @dev Called by the rollup to pull messages
   * @dev We take the next `_toConsumeCount` entries to reduce the ability to "skip" messages
   * @param _toConsumeCount - The number of messages we want to consume
   * @return totalConsumed - The total number of consumed messages
   * @return consumed - Hashes of the consumed entries
   */
  function chug(uint256 _toConsumeCount)
    external
    returns (uint256 totalConsumed, bytes32[] memory consumed)
  {
    if (msg.sender != ROLLUP) revert Unauthorized();
    totalConsumed = consumeCount;
    uint256 consumables = messageCount;
    uint256 toConsume;
    if (_toConsumeCount > consumables) {
      toConsume = consumables;
    } else {
      toConsume = _toConsumeCount;
    }

    consumed = new bytes32[](toConsume);

    for (uint256 i = 0; i < toConsume; i++) {
      consumed[i] = entries[totalConsumed + i];
    }

    totalConsumed += toConsume;

    consumeCount = totalConsumed;
    return (totalConsumed, consumed);
  }
}
