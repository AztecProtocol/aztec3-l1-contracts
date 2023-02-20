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
}
