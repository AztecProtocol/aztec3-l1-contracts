// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

contract Broadcaster {
  event Yeet(bytes rawBytes);

  function yeet(bytes calldata _raw) external {
    emit Yeet(_raw);
  }
}
