// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

import {MockVerifier} from "@aztec3/mock/MockVerifier.sol";

import {Decoder} from "./Decoder.sol";

/**
 * @title Rollup
 * @author LHerskind
 * @notice Rollup contract that are concerned about readability and velocity of development
 * not giving a damn about gas costs.
 *
 * Work in progress
 */
contract Rollup is Decoder {
  error InvalidStateHash(bytes32 expected, bytes32 actual);
  error InvalidProof();

  event RollupBlockProcessed(uint256 indexed rollupBlockNumber);

  MockVerifier public immutable verifier;

  bytes32 public rollupStateHash;

  constructor() {
    verifier = new MockVerifier();
  }

  function processRollup(bytes memory _proof, bytes memory _inputs) external {
    (uint256 rollupBlockNumber, bytes32 oldStateHash, bytes32 newStateHash, bytes32 publicInputHash)
    = _decode(_inputs);

    // @todo Proper genesis state. If the state is empty, we allow anything for now.
    if (rollupStateHash != bytes32(0) && rollupStateHash != oldStateHash) {
      revert InvalidStateHash(rollupStateHash, oldStateHash);
    }

    bytes32[] memory publicInputs = new bytes32[](1);
    publicInputs[0] = publicInputHash;

    if (!verifier.verify(_proof, publicInputs)) {
      revert InvalidProof();
    }

    rollupStateHash = newStateHash;

    emit RollupBlockProcessed(rollupBlockNumber);
  }
}
