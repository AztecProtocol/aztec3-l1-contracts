// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

contract MockVerifier {
  function getVerificationKeyHash() public pure returns (bytes32) {
    return bytes32("Im a mock");
  }

  function verify(bytes calldata _proof, bytes32[] calldata _inputs) external view returns (bool) {
    return true;
  }
}
