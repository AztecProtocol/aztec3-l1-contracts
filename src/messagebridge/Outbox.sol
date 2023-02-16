// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

contract Outbox {
  error InvalidCaller(address caller, address expected);
  error CallerRequired(address expected);
  error FailingPortalCall(bytes reason);
  error NothingToConsume();
  error Unauthorized();
  error InvalidFormat();
  error MessageNotConsumed();

  event Consumed(address indexed portal, bytes32 indexed messageHash);

  address immutable ROLLUP;

  /**
   * @notice Entry into the outbox messages
   * @param caller - The address that can initate, address(0) if anyone can call
   * @param exists - A flag that is true if the entry exists, and is consumable, false otherwise
   */
  struct OutboxEntry {
    address caller;
    bool exists;
  }

  // entryKey = keccak256(address portal, bytes32 msgHash)
  mapping(bytes32 entryKey => OutboxEntry entry) entries;

  constructor() {
    ROLLUP = msg.sender;
  }

  /**
   * @notice Inserts a message into the outbox.
   * @dev Note, that we don't enforce any duplicate protection
   * This needs to be handled on the application layer to ensure that
   * duplicates can all be executed.
   * @dev Only callable by the rollup, reverts otherwise
   * @dev Reverts if list lengths differ
   * @param _portals - A list of portals that are to be called
   * @param _callers - A list of designated callers
   * @param _msgHashes - A list of the content hashes for the calls
   */
  function receiveMessages(
    address[] memory _portals,
    address[] memory _callers,
    bytes32[] memory _msgHashes
  ) external {
    if (msg.sender != ROLLUP) revert Unauthorized();
    if (_msgHashes.length != _portals.length) revert InvalidFormat();
    if (_msgHashes.length != _callers.length) revert InvalidFormat();

    for (uint256 i = 0; i < _msgHashes.length; i++) {
      bytes32 entryKey = keccak256(abi.encode(_portals[i], _msgHashes[i]));
      entries[entryKey] = OutboxEntry({caller: _callers[i], exists: true});
    }
  }

  /**
   * @notice Consumes a message from the outbox
   * @dev Only callable by the portal that receives the message
   * @dev The `caller` should be seen as a "request"
   * @param _content - The content of the message
   */
  function consume(bytes memory _content) external {
    bytes32 msgHash = sha256(_content);
    bytes32 entryKey = keccak256(abi.encode(msg.sender, msgHash));

    OutboxEntry storage entry = entries[entryKey];
    if (!entry.exists) revert NothingToConsume();
    if (entry.caller != address(0)) revert CallerRequired(entry.caller);

    delete entries[entryKey];
    emit Consumed(msg.sender, msgHash);
  }

  /**
   * @notice Will "prepare" for an entry with designated caller to be consumed by a portal AND call the portal
   * with the provided `_data`.
   * @dev An entry with a designated caller must be initiated by the specified caller, as we can use this
   * to handle ordering of multiple entries. As consumption can't do this directly, `msg.sender` already populated
   * with portal, we perform this call, which "removes" the requirement on `consume` and then perform a call
   * on the portal. If the message have not been consumed after this call, this function will revert.
   * @param _data - Calldata to be used for a call on `entry.portal`
   * @param _content - The content of the message we are designated caller for
   */
  function designatedConsume(address _portal, bytes memory _data, bytes memory _content) external {
    bytes32 msgHash = sha256(_content);
    bytes32 entryKey = keccak256(abi.encode(_portal, msgHash));

    // Note: Storage pointer, not in memory
    OutboxEntry storage entry = entries[entryKey];
    if (!entry.exists) revert NothingToConsume();
    if (entry.caller != msg.sender) revert InvalidCaller(msg.sender, entry.caller);

    entry.caller = address(0);

    // External call that potentially reenter. How can we abuse this reenter?
    (bool success, bytes memory returnData) = _portal.call(_data);
    if (!success) revert FailingPortalCall(returnData);

    if (entry.exists) revert MessageNotConsumed();
  }

  function getEntry(address _portal, bytes32 _msgHash) external view returns (OutboxEntry memory) {
    bytes32 entryKey = keccak256(abi.encode(_portal, _msgHash));
    return entries[entryKey];
  }

  function getEntry(bytes32 _entryKey) external view returns (OutboxEntry memory) {
    return entries[_entryKey];
  }
}
