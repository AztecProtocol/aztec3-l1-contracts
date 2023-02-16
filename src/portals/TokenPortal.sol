// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";

import {Rollup} from "../Rollup.sol";
import {Inbox} from "../messagebridge/Inbox.sol";
import {Outbox} from "../messagebridge/Outbox.sol";

contract TokenPortal {
  using SafeERC20 for IERC20;

  Inbox public immutable INBOX;
  Outbox public immutable OUTBOX;
  IERC20 public immutable ASSET;

  constructor(Rollup _rollup, IERC20 _asset) {
    INBOX = _rollup.INBOX();
    OUTBOX = _rollup.OUTBOX();
    ASSET = _asset;
  }

  /**
   * @notice Deposit funds into the portal and adds an L2 message.
   * @param _amount - The amount to transfer
   * @param _to - The aztec address of the recipient
   * @return The index in the message list
   */
  function deposit(uint256 _amount, bytes32 _to) external returns (uint256) {
    bytes memory message = abi.encode(_amount, _to);
    ASSET.safeTransferFrom(msg.sender, address(this), _amount);
    return INBOX.sendL2Message(message);
  }

  /**
   * @notice Withdraw funds from the portal
   * @dev Will revert if not matching entry in outbox
   * @param _amount - The amount to withdraw
   * @param _to - The address to withdraw to
   */
  function withdraw(uint256 _amount, address _to) external {
    bytes memory message = abi.encode(_amount, _to);
    OUTBOX.consume(message);
    ASSET.safeTransfer(_to, _amount);
  }
}
