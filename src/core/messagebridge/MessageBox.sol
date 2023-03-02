// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

/**
 * @title MessageBox
 * @author LHerskind
 * @notice Data structure used in both Inbox and Outbox for keeping track of entries
 * Implements a multi-set storing the multiplicity (count for easy reading) at the entry.
 */
abstract contract MessageBox {
  error NothingToConsume(bytes32 entryKey);
  error OversizedContent();

  uint256 public constant MESSAGE_SIZE = 256;

  /**
   * @dev Entry struct - Done as struct to easily support extensions if needed
   * @param count - The occurrence of the entry in the dataset
   */
  struct Entry {
    uint256 count;
  }

  mapping(bytes32 entryKey => Entry entry) internal entries;

  /**
   * @notice Inserts an entry into the multi-set
   * @param _entryKey - The key to insert
   */
  function _insert(bytes32 _entryKey) internal {
    entries[_entryKey].count++;
  }

  /**
   * @notice Consumed an entry if possible, reverts if nothing to consume
   * For multiplicity > 1, will consume one element
   * @param _entryKey - The key to consume
   */
  function _consume(bytes32 _entryKey) internal {
    Entry storage entry = entries[_entryKey];
    if (entry.count == 0) revert NothingToConsume(_entryKey);
    entry.count--;
  }

  /**
   * @notice Fetch an entry
   * @param _entryKey - The key to lookup
   * @return The entry matching the provided key
   */
  function get(bytes32 _entryKey) public view returns (Entry memory) {
    Entry memory entry = entries[_entryKey];
    if (entry.count == 0) revert NothingToConsume(_entryKey);
    return entry;
  }

  /**
   * @notice Check if entry exists
   * @param _entryKey - The key to lookup
   * @return True if entry exists, false otherwise
   */
  function contains(bytes32 _entryKey) public view returns (bool) {
    return entries[_entryKey].count > 0;
  }

  function _padEntry(bytes memory _content) internal pure returns (bytes memory) {
    if (_content.length > MESSAGE_SIZE) revert OversizedContent();

    if (_content.length == MESSAGE_SIZE) {
      return _content;
    }

    bytes memory content = new bytes(MESSAGE_SIZE);
    // Horrible, but lets do this for now just to try stuff.
    for (uint256 i = 0; i < _content.length; i++) {
      content[i] = _content[i];
    }
    return content;
  }
}
