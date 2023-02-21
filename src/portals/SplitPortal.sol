// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";

import {Rollup} from "../Rollup.sol";
import {Inbox} from "../messagebridge/Inbox.sol";
import {Outbox} from "../messagebridge/Outbox.sol";
import {TokenPortal} from "./TokenPortal.sol";

/**
 * @title SplitPortal
 * @author LHerskind
 * @notice Portal that withdraws funds using a TokenPortal and then "splits" the amount
 * between multiple participants following a distribution key provided as part of the transaction.
 */
contract SplitPortal {
  using SafeERC20 for IERC20;

  error InvalidLengths();

  Inbox public immutable INBOX;
  Outbox public immutable OUTBOX;

  constructor(Rollup _rollup) {
    INBOX = _rollup.INBOX();
    OUTBOX = _rollup.OUTBOX();
  }

  /**
   * @notice Withdraw funds from L2 and distribute them between recipients
   * @dev Requires the TokenPortal to implement `caller` for proper execution
   * @dev Consumes 2 messages, one for the token portal, and one for itself
   * @param _tokenPortal - The ethereum address of the portal contract
   * @param _recipients - The ethereum addresses of the recipients
   * @param _amounts - The amounts to transfer to the recipients
   * @param _withCaller - Flag to use `msg.sender` as caller, otherwise using address(0)
   */
  function split(
    address _tokenPortal,
    address[] memory _recipients,
    uint256[] memory _amounts,
    bool _withCaller
  ) external {
    if (_recipients.length != _amounts.length) revert InvalidLengths();
    uint256 sum = 0;
    for (uint256 i = 0; i < _amounts.length; i++) {
      sum += _amounts[i];
    }

    TokenPortal(_tokenPortal).withdraw(sum, address(this), true);

    bytes32 recipients = keccak256(abi.encode(_recipients));
    bytes32 amounts = keccak256(abi.encode(_amounts));

    OUTBOX.consume(
      abi.encodeWithSignature(
        "split(address,bytes32,bytes32,address)",
        _tokenPortal,
        recipients,
        amounts,
        _withCaller ? msg.sender : address(0)
      )
    );

    IERC20 token = TokenPortal(_tokenPortal).ASSET();
    for (uint256 i = 0; i < _amounts.length; i++) {
      token.safeTransfer(_recipients[i], _amounts[i]);
    }
  }
}
