// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

/**
 * @title Rolodex
 * @author LHerskind
 * @notice A registry for L1 <-> L2 contract mappings.
 */
contract Rolodex {
  error Unauthorized();
  error AlreadyListed(address portal, bytes32 l2Address);
  error InvalidInput(address portal, bytes32 l2Address);

  event AddedLink(address portal, bytes32 l2Address);

  address immutable ROLLUP;

  mapping(address portal => bytes32 l2Address) public l2Contracts;
  mapping(bytes32 l2Address => address portal) public portals;

  constructor() {
    ROLLUP = msg.sender;
  }

  function addLink(address _portal, bytes32 _l2Address) external returns (bool) {
    if (msg.sender != ROLLUP) revert Unauthorized();
    if (_l2Address == bytes32(0)) revert InvalidInput(_portal, _l2Address);
    if (_portal == address(0)) revert InvalidInput(_portal, _l2Address);
    if (l2Contracts[_portal] != bytes32(0) || portals[_l2Address] != address(0)) {
      revert AlreadyListed(_portal, _l2Address);
    }

    l2Contracts[_portal] = _l2Address;
    portals[_l2Address] = _portal;

    emit AddedLink(_portal, _l2Address);
    return true;
  }
}
