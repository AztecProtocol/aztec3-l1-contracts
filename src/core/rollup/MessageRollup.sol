// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

import {Rolodex} from "../messagebridge/Rolodex.sol";
import {Inbox} from "../messagebridge/Inbox.sol";
import {Outbox} from "../messagebridge/Outbox.sol";

contract MessageRollup {
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

  function chugMessages(
    address _feeBeneficiary,
    bytes32[] memory _l2Addresses,
    uint256[] memory _deadlines,
    uint256[] memory _fees,
    bytes[] memory _contents
  ) public {
    if (_l2Addresses.length != _deadlines.length) revert InvalidFormat();
    if (_l2Addresses.length != _fees.length) revert InvalidFormat();
    if (_l2Addresses.length != _contents.length) revert InvalidFormat();

    for (uint256 i = 0; i < _l2Addresses.length; i++) {
      INBOX.consume(
        _feeBeneficiary, ROLODEX.portals(_l2Addresses[i]), _deadlines[i], _fees[i], _contents[i]
      );
    }
  }

  /**
   * @notice Takes messages received from L2, and puts them into the outbox on L1
   * To be executed as part of the process rollup -> Validation except finding portal address performed inside proof
   */
  function messageDelivery(bytes32[] memory _l2Addresses, bytes[] memory _contents) public {
    for (uint256 i = 0; i < _l2Addresses.length; i++) {
      OUTBOX.sendL1Message(ROLODEX.portals(_l2Addresses[i]), _contents[i]);
    }
  }
}
