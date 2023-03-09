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
  error InvalidProof();

  event RollupBlockProcessed(uint256 indexed rollupBlockNumber);

  MockVerifier public immutable verifier;

  constructor() {
    verifier = new MockVerifier();
  }

  function processRollup(bytes memory _proof, bytes memory _inputs) external {
    uint256 rollupBlockId = _getRollupBlockId(_inputs);
    (uint256 commitmentCount, bytes32 newCommitmentHash) =
      _computeCommitmentsOrNullifierRoot(_inputs, 0x16c);
    // emit log_named_uint("commitmentCount", commitmentCount);
    // emit log_named_bytes32("newCommitmentHash", newCommitmentHash);

    (uint256 nullifierCount, bytes32 newNullifierHash) =
      _computeCommitmentsOrNullifierRoot(_inputs, 0x170 + commitmentCount * 0x20);
    // emit log_named_uint("nullifierCount", nullifierCount);
    // emit log_named_bytes32("newNullifierHash", newNullifierHash);

    (uint256 contractCount, bytes32 contractHash) =
      _computeContractsRoot(_inputs, 0x174 + (commitmentCount + nullifierCount) * 0x20);
    // emit log_named_uint("contractCount", contractCount);
    // emit log_named_bytes32("contractHash", contractHash);

    bytes32 contractDataHash = _computeContractsDataRoot(
      _inputs, 0x174 + (commitmentCount + nullifierCount + contractCount) * 0x20, contractCount
    );
    // emit log_named_bytes32("contractDataHash", contractDataHash);

    bytes32[] memory publicInputs = new bytes32[](1);

    // @todo Compute the public input hash using all the values computed and provided instead of this.
    publicInputs[0] = sha256(_inputs);

    if (!verifier.verify(_proof, publicInputs)) {
      revert InvalidProof();
    }

    emit RollupBlockProcessed(rollupBlockId);
  }
}
