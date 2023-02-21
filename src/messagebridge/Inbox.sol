// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

import {Rolodex} from "./Rolodex.sol";
import {MessageBox} from "./MessageBox.sol";

/**
 * @title Inbox
 * @author LHerskind
 * @notice Used to pass messages into the rollup, e.g., L1 -> L2 messages.
 */
contract Inbox is MessageBox {
  error NotPastDeadline();
  error Unauthorized();
  error NotPortal(address caller);

  event MessageAdded(
    bytes32 indexed entryKey,
    bytes32 indexed l2Address,
    address indexed portal,
    uint256 deadline,
    uint256 fee,
    bytes content
  );

  Rolodex immutable ROLODEX;
  address immutable ROLLUP;

  mapping(address account => uint256 balance) public feesAccrued;

  constructor(Rolodex _rolodex) {
    ROLLUP = msg.sender;
    ROLODEX = _rolodex;
  }

  /**
   * @notice Computes an entry key for the Inbox
   * @param _portal - The ethereum address of the portal
   * @param _deadline - The timestamp after which the entry can be cancelled
   * @param _fee - The fee provided to sequencer for including the entry
   * @param _content - The content of the entry (application specific)
   * @return The key of the entry in the set
   */
  function computeEntryKey(address _portal, uint256 _deadline, uint256 _fee, bytes memory _content)
    public
    pure
    returns (bytes32)
  { 
    return keccak256(abi.encode(_portal, _deadline, _fee, _padEntry(_content)));
  }

  /**
   * @notice Inserts an entry into the Inbox
   * @dev Only callable by contracts that are portals according to the Rolodex
   * @dev Will emit `MessageAdded` with data for easy access by the sequencer
   * @dev msg.value - The fee provided to sequencer for including the entry
   * @param _deadline - The timestamp after which the entry can be cancelled
   * @param _content - The content of the entry (application specific)
   * @return The key of the entry in the set
   */
  function sendL2Message(uint256 _deadline, bytes memory _content)
    external
    payable
    returns (bytes32)
  {
    bytes32 l2Address = ROLODEX.l2Contracts(msg.sender);
    if (l2Address == bytes32(0)) revert NotPortal(msg.sender);
    bytes32 entryKey = computeEntryKey(msg.sender, _deadline, msg.value, _content);
    _insert(entryKey);
    emit MessageAdded(entryKey, l2Address, msg.sender, _deadline, msg.value, _content);
    return entryKey;
  }

  /**
   * @notice Cancel a pending L2 message
   * @dev Will revert if the deadline have not been crossed
   * @dev Must be called by portal that inserted the entry
   * @param _feeCollector - The address to receive the "fee"
   * @param _deadline - The timestamp after which the entry can be cancelled
   * @param _fee - The fee provided to sequencer for including the entry
   * @param _content - The content of the entry (application specific)
   * @return The key of the entry removed
   */
  function cancelL2Message(
    address _feeCollector,
    uint256 _deadline,
    uint256 _fee,
    bytes memory _content
  ) external returns (bytes32) {
    if (_deadline < block.timestamp) revert NotPastDeadline();
    bytes32 entryKey = computeEntryKey(msg.sender, _deadline, _fee, _content);
    _consume(entryKey);
    feesAccrued[_feeCollector] += _fee;
    return entryKey;
  }

  /**
   * @notice Consumes an entry from the Inbox
   * @dev Only callable by the rollup contract
   * @param _feeCollector - The address to receive the "fee"
   * @param _portal - The ethereum address of the portal
   * @param _deadline - The timestamp after which the entry can be cancelled
   * @param _fee - The fee provided to sequencer for including the entry
   * @param _content - The content of the entry (application specific)
   * @return The key of the entry removed
   */
  function consume(
    address _feeCollector,
    address _portal,
    uint256 _deadline,
    uint256 _fee,
    bytes memory _content
  ) external returns (bytes32) {
    if (msg.sender != ROLLUP) revert Unauthorized();
    bytes32 entryKey = computeEntryKey(_portal, _deadline, _fee, _content);
    _consume(entryKey);
    feesAccrued[_feeCollector] += _fee;
    return entryKey;
  }
}
