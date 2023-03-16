// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

/**
 * @title Yeeter
 * @author LHerskind
 * @notice The Yeeter is loud, but don't know what he is saying.
 * Assume everything he tells you are lies.
 */
contract Yeeter {
  /**
   * @notice Event to convey linking of L1 and L2 addresses
   * @param aztecAddress - The address of the L2 counterparty
   * @param portalAddress - The address of the L1 counterparty
   * @param acir - The acir bytecode of the L2 contract
   */
  event ContractDeploymentYeet(
    bytes32 indexed aztecAddress, address indexed portalAddress, bytes acir
  );
  /**
   * @notice Event to share possibly useful data
   * @param l2blockNum - The L2 block number that the information is related to
   * @param sender - The address of the account sharing the information
   * @param blabber - The information in raw bytes
   */
  event Yeet(uint256 indexed l2blockNum, address indexed sender, bytes blabber);

  /**
   * @notice Yeets data out on chain
   * @dev Emits a `Yeet` event
   * @param _l2blockNum - The l2 block number that the yeet is related to
   * @param _blabber - The data we want people do know as raw bytes
   */
  function yeet(uint256 _l2blockNum, bytes calldata _blabber) external {
    emit Yeet(_l2blockNum, msg.sender, _blabber);
  }

  /**
   * @notice Yeets
   * @dev Emits a `ContractDeploymentYeet` event
   * @param _aztecAddress - The address of the L2 counterparty
   * @param _portalAddress - The address of the L1 counterparty
   * @param _acir - The acir bytecode of the L2 contract
   */
  function yeetContractDeployment(
    bytes32 _aztecAddress,
    address _portalAddress,
    bytes calldata _acir
  ) external {
    emit ContractDeploymentYeet(_aztecAddress, _portalAddress, _acir);
  }
}
