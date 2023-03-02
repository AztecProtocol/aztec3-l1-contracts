// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

import {MockVerifier} from "@aztec3/mock/MockVerifier.sol";

contract BaseRollup {
  error InvalidProof();

  struct RollupState {
    uint256 rollupId;
    bytes32 stateHash;
  }

  MockVerifier public immutable verifier;
  RollupState public state;

  constructor() {
    verifier = new MockVerifier();
  }

  function processRollup(bytes memory _proof, bytes memory _inputs) external {
    bytes32[] memory publicInputs = new bytes32[](1);
    publicInputs[0] = sha256(_inputs);

    if (!verifier.verify(_proof, publicInputs)) {
      revert InvalidProof();
    }
    // @todo Check that value from _proof matches the current state
    // @todo Update state.stateHash to value from _proof that is the next state
    state.rollupId += 1;
  }
}
