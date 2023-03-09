// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

/**
 * @title Yeeter
 * @author LHerskind
 * @notice The Yeeter is loud, but don't check what he is saying.
 * Assume everything he tells you are lies.
 */
contract Yeeter {
  event ContractDeployment(bytes32 indexed aztecAddress, address indexed portalAddress, bytes acir);

  event Yeet(address indexed sender, bytes blabber);

  function yeet(bytes calldata _blabber) external {
    emit Yeet(msg.sender, _blabber);
  }

  function yeetContractDeployment(
    bytes32 _aztecAddress,
    address _portalAddress,
    bytes calldata _acir
  ) external {
    emit ContractDeployment(_aztecAddress, _portalAddress, _acir);
  }
}
