// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

import {MessageBox} from "./MessageBox.sol";

/**
 * @title Outbox
 * @author LHerskind
 * @notice Used to consume L2 -> L1 messages. Messages are inserted by the rollup contract
 * and will be consumed by the portal contracts
 */
contract Outbox is MessageBox {
  error InvalidCaller(address caller, address expected);
  error CallerRequired(address expected);
  error FailingPortalCall(bytes reason);
  error Unauthorized();
  error InvalidFormat();
  error MessageNotConsumed();

  event Consumed(address indexed portal, bytes32 indexed entryKey);

  address immutable ROLLUP;

  constructor() {
    ROLLUP = msg.sender;
  }

  /**
   * @notice Computes an entry key for the Outbox
   * @param _portal - The ethereum address of the portal
   * @param _content - The content of the entry (application specific)
   * @return The key of the entry in the set
   */
  function computeEntryKey(address _portal, bytes memory _content) public pure returns (bytes32) {
    return keccak256(abi.encode(_portal, _content));
  }

  /**
   * @notice Inserts an entry into the Outbox
   * @dev Only callable by the rollup contract
   * @param _portal - The ethereum address of the portal
   * @param _content - The content of the entry (application specific)
   * @return The key of the entry in the set
   */
  function sendL1Message(address _portal, bytes memory _content) external returns (bytes32) {
    if (msg.sender != ROLLUP) revert Unauthorized();
    bytes32 entryKey = computeEntryKey(_portal, _content);
    _insert(entryKey);
    return entryKey;
  }

  /**
   * @notice Consumes an entry from the Outbox
   * @dev Only meaningfully callable by portals, otherwise should never hit an entry
   * @dev Emits the `Consumed` event when consuming messages
   * @param _content - The content of the entry (application specific)
   * @return The key of the entry removed
   */
  function consume(bytes memory _content) external returns (bytes32) {
    bytes32 entryKey = computeEntryKey(msg.sender, _content);
    _consume(entryKey);
    emit Consumed(msg.sender, entryKey);
    return entryKey;
  }
}
