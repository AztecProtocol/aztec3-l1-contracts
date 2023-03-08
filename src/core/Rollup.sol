// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

import {MockVerifier} from "@aztec3/mock/MockVerifier.sol";

contract Rollup {
    error InvalidProof();

    MockVerifier public immutable verifier;

    constructor() {
        verifier = new MockVerifier();
    }

    function processRollup(bytes memory _proof, bytes memory _inputs) external {
        bytes32[] memory publicInputs = new bytes32[](1);
        publicInputs[0] = sha256(_inputs);

        if (!verifier.verify(_proof, publicInputs)) {
            revert InvalidProof();
        }
    }
}
