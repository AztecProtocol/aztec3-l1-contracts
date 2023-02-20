// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";

import {Rollup} from "../Rollup.sol";
import {Inbox} from "../messagebridge/Inbox.sol";
import {Outbox} from "../messagebridge/Outbox.sol";
import {TokenPortal} from "./TokenPortal.sol";

import {ISwapRouter} from "../external/ISwapRouter.sol";

/**
 * @title UniswapPortal
 * @author LHerskind
 * @notice A minimal portal that allow an user inside L2, to withdraw asset A from the Rollup
 * swap asset A to asset B, and deposit asset B into the rollup again.
 * Relies on Uniswap for doing the swap, TokenPortals for A and B to get and send tokens
 * and the message boxes (inbox & outbox).
 */
contract UniswapPortal {
  using SafeERC20 for IERC20;

  ISwapRouter public constant ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
  Inbox public immutable INBOX;
  Outbox public immutable OUTBOX;

  constructor(Rollup _rollup) {
    INBOX = _rollup.INBOX();
    OUTBOX = _rollup.OUTBOX();
  }

  /**
   * @notice Exit with funds from L2, perform swap on L1 and deposit output asset to L2 again
   * @dev Currently not handling the fee for the message added to `Inbox`, to be implemented
   * @param _inputTokenPortal - The ethereum address of the input token portal
   * @param _inAmount - The amount of assets to swap (same amount as withdrawn from L2)
   * @param _fee - The fee tier for the swap on UniswapV3
   * @param _outputTokenPortal - The ethereum address of the output token portal
   * @param _aztecRecipient - The aztec address to receive the output assets
   * @param _canceller - The ethereum address that can cancel the deposit
   * @param _withCaller - Flag to use `msg.sender` as caller, otherwise using address(0)
   * @return The entryKey of the deposit transaction in the Inbox
   */
  function swap(
    address _inputTokenPortal,
    uint256 _inAmount,
    uint24 _fee,
    address _outputTokenPortal,
    bytes32 _aztecRecipient,
    address _canceller,
    bool _withCaller
  ) public returns (bytes32) {
    IERC20 inputAsset = TokenPortal(_inputTokenPortal).ASSET();
    IERC20 outputAsset = TokenPortal(_outputTokenPortal).ASSET();

    TokenPortal(_inputTokenPortal).withdraw(_inAmount, address(this), true);

    // Consume the message
    OUTBOX.consume(
      abi.encodeWithSignature(
        "swap(address,uint256,uint24,address,bytes32,address,address)",
        _inputTokenPortal,
        _inAmount,
        _fee,
        _outputTokenPortal,
        _aztecRecipient,
        _withCaller ? msg.sender : address(0)
      )
    );

    // Perform the swap
    inputAsset.safeApprove(address(ROUTER), _inAmount);
    uint256 amountOut = ROUTER.exactInputSingle(
      ISwapRouter.ExactInputSingleParams({
        tokenIn: address(inputAsset),
        tokenOut: address(outputAsset),
        fee: _fee,
        recipient: address(this),
        deadline: block.timestamp,
        amountIn: _inAmount,
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
      })
    );

    // @note We are not dealing with the fee in here. We gotta have some way to either pass it along, or have someone else pay the amount.
    // Possibly we should allow someone else to come in and pay the fee, but only the amount specified already? Its a bit of a hurdle. How to pay this.
    outputAsset.safeApprove(address(_outputTokenPortal), amountOut);
    return TokenPortal(_outputTokenPortal).deposit(
      amountOut, _aztecRecipient, bytes32(0), block.timestamp, _canceller
    );
  }
}
