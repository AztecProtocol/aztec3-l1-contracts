// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";

import {Rollup} from "../Rollup.sol";
import {Inbox} from "../messagebridge/Inbox.sol";
import {Outbox} from "../messagebridge/Outbox.sol";
import {TokenPortal} from "./TokenPortal.sol";

contract SplitPortal {
  using SafeERC20 for IERC20;

  error InvalidAmountReceived();
  error InvalidLengths();

  Inbox public immutable INBOX;
  Outbox public immutable OUTBOX;

  constructor(Rollup _rollup) {
    INBOX = _rollup.INBOX();
    OUTBOX = _rollup.OUTBOX();
  }

  function split(address _tokenPortal, address[] memory _recipients, uint256[] memory _amounts)
    external
  {
    if (_recipients.length != _amounts.length) revert InvalidAmountReceived();

    uint256 sum = 0;
    for (uint256 i = 0; i < _amounts.length; i++) {
      sum += _amounts[i];
    }

    IERC20 token = TokenPortal(_tokenPortal).ASSET();
    uint256 balanceBefore = token.balanceOf(address(this));

    // Execute "preparation" consumption. Withdrawal of token from the token portal
    {
      bytes memory content = abi.encode(sum, address(this));
      bytes memory data = abi.encodeWithSelector(TokenPortal.withdraw.selector, sum, address(this));
      OUTBOX.designatedConsume(_tokenPortal, data, content);
    }

    // Check that we received the correct amount of tokens
    uint256 tokensReceived = token.balanceOf(address(this)) - balanceBefore;
    if (tokensReceived != sum) revert InvalidAmountReceived();

    // Consume the message related to the SplitPortal contract
    bytes memory content = abi.encode(_tokenPortal, _recipients, _amounts);
    OUTBOX.consume(content);

    for (uint256 i = 0; i < _amounts.length; i++) {
      token.safeTransfer(_recipients[i], _amounts[i]);
    }
  }
}
