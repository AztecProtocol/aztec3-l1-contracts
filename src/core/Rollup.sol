// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

/**
 * @title Rollup
 * @author LHerskind
 * @notice Rollup contract that are concerned about readability and velocity of development
 * not giving a damn about gas costs.
 *
 * Work in progress
 */
contract Rollup {
  event L2BlockProcessed(uint256 indexed blockNum);

  uint256 public latestBlockNum = 0;

  function processRollup() external {
    emit L2BlockProcessed(latestBlockNum++);
  }
}
