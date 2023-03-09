// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

/**
 * @title Decoder
 * @author LHerskind
 * @notice Decoding a rollup block, concerned with readability and velocity of development
 * not giving a damn about gas costs.
 *
 * -------------------
 * Data specification
 * -------------------
 *
 *  | byte start               | num bytes  | name
 *  | ---                      | ---        | ---
 *  | 0x00                     | 0x04       | rollup block id
 *  | 0x04                     | 0x04       | startPrivateDataTreeSnapshot.nextAvailableLeafIndex
 *  | 0x08                     | 0x20       | startPrivateDataTreeSnapshot.root
 *  | 0x28                     | 0x04       | startNullifierTreeSnapshot.nextAvailableLeafIndex
 *  | 0x2c                     | 0x20       | startNullifierTreeSnapshot.root
 *  | 0x4c                     | 0x04       | startContractTreeSnapshot.nextAvailableLeafIndex
 *  | 0x50                     | 0x20       | startContractTreeSnapshot.root
 *  | 0x70                     | 0x04       | startTreeOfHistoricPrivateDataTreeRootsSnapshot.nextAvailableLeafIndex
 *  | 0x74                     | 0x20       | startTreeOfHistoricPrivateDataTreeRootsSnapshot.root
 *  | 0x94                     | 0x04       | startTreeOfHistoricContractTreeRootsSnapshot.nextAvailableLeafIndex
 *  | 0x98                     | 0x20       | startTreeOfHistoricContractTreeRootsSnapshot.root
 *  | 0x9c                     | 0x04       | endPrivateDataTreeSnapshot.nextAvailableLeafIndex
 *  | 0xbc                     | 0x20       | endPrivateDataTreeSnapshot.root
 *  | 0xc0                     | 0x04       | endNullifierTreeSnapshot.nextAvailableLeafIndex
 *  | 0xe0                     | 0x20       | endNullifierTreeSnapshot.root
 *  | 0xe4                     | 0x04       | endContractTreeSnapshot.nextAvailableLeafIndex
 *  | 0x104                    | 0x20       | endContractTreeSnapshot.root
 *  | 0x124                    | 0x04       | endTreeOfHistoricPrivateDataTreeRootsSnapshot.nextAvailableLeafIndex
 *  | 0x128                    | 0x20       | endTreeOfHistoricPrivateDataTreeRootsSnapshot.root
 *  | 0x148                    | 0x04       | endTreeOfHistoricContractTreeRootsSnapshot.nextAvailableLeafIndex
 *  | 0x14c                    | 0x20       | endTreeOfHistoricContractTreeRootsSnapshot.root
 *  | 0x16c                    | 0x04       | len(newCommitments) denoted x
 *  | 0x170                    | x          | newCommits
 *  | 0x170 + x                | 0x04       | len(newNullifiers) denoted y
 *  | 0x174 + x                | y          | newNullifiers
 *  | 0x174 + x + y            | 0x04       | len(newContracts) denoted z
 *  | 0x178 + x + y            | z          | newContracts
 *  | 0x178 + x + y + z        | z          | newContractData
 *  |---                       |---         | ---
 *
 * At this stage, we are not super concerned about the gas usage. So we will be making implementation that use more than necessary memory to make it simpler to change later on
 *
 * note: there is currently no padding of the elements, so we are for now assuming nice trees as inputs.
 */
contract Decoder {
  function _getRollupBlockId(bytes memory _inputData) internal pure returns (uint256 rollupBlockId) {
    assembly {
      rollupBlockId := and(shr(224, mload(add(_inputData, 0x20))), 0xffffffff)
    }
  }

  /**
   * @notice Computes a root of a commitment or nullifier subtree
   * @param _inputData - The raw input bytes as specified above.
   * @param _offset - The offset to land at "len(newCommits)" or "len(newNullifiers)"
   */
  function _computeCommitmentsOrNullifierRoot(bytes memory _inputData, uint256 _offset)
    internal
    view
    returns (uint256 size, bytes32)
  {
    // @todo: Must insert empty leafs to

    uint256 elementsPerLeaf = 8;
    assembly {
      size := and(shr(224, mload(add(_inputData, add(_offset, 0x20)))), 0xffffffff)
    }

    // Compute the leafs. Each leaf is 8 elements
    bytes32[] memory leafs = new bytes32[](size / elementsPerLeaf);
    for (uint256 i = 0; i < size / elementsPerLeaf; i++) {
      uint256 src = 0x04 + 0x20 + _offset + i * 8 * 0x20;
      bytes memory inputValue = new bytes(0x100);
      // inputValue = _inputData[src:src+256]
      assembly {
        pop(staticcall(gas(), 0x4, add(_inputData, src), 0x100, add(inputValue, 0x20), 0x100))
      }
      leafs[i] = sha256(inputValue);
    }

    bytes32 root = _computeRoot(leafs);

    return (size, root);
  }

  function _computeContractsRoot(bytes memory _inputData, uint256 _offset)
    internal
    view
    returns (uint256 size, bytes32)
  {
    uint256 elementsPerLeaf = 2;
    assembly {
      size := and(shr(224, mload(add(_inputData, add(_offset, 0x20)))), 0xffffffff)
    }

    // Compute the leafs. Each leaf is 2
    bytes32[] memory leafs = new bytes32[](size / elementsPerLeaf);
    for (uint256 i = 0; i < size / elementsPerLeaf; i++) {
      uint256 src = 0x04 + 0x20 + _offset + i * 0x40;
      bytes memory inputValue = new bytes(0x40);
      // inputValue = _inputData[src:src+64]
      assembly {
        pop(staticcall(gas(), 0x4, add(_inputData, src), 0x40, add(inputValue, 0x20), 0x40))
      }
      leafs[i] = sha256(inputValue);
    }

    return (size, _computeRoot(leafs));
  }

  function _computeContractsDataRoot(bytes memory _inputData, uint256 _offset, uint256 _size)
    internal
    view
    returns (bytes32)
  {
    uint256 elementsPerLeaf = 2;

    // Compute the leafs. Each leaf is 2
    bytes32[] memory leafs = new bytes32[](_size / elementsPerLeaf);
    for (uint256 i = 0; i < _size / elementsPerLeaf; i++) {
      uint256 src = 0x04 + 0x20 + _offset + i * 0x68;
      bytes memory inputValue = new bytes(0x68);
      // inputValue = _inputData[src:src+108]
      assembly {
        pop(staticcall(gas(), 0x4, add(_inputData, src), 0x68, add(inputValue, 0x20), 0x68))
      }
      leafs[i] = sha256(inputValue);
    }

    return _computeRoot(leafs);
  }

  function _computeRoot(bytes32[] memory _leafs) internal pure returns (bytes32) {
    uint256 treeDepth = 0;
    while (2 ** treeDepth < _leafs.length) {
      treeDepth++;
    }
    uint256 treeSize = 2 ** treeDepth;
    assembly {
      mstore(_leafs, treeSize)
    }

    for (uint256 i = 0; i < treeDepth; i++) {
      for (uint256 j = 0; j < treeSize; j += 2) {
        _leafs[j / 2] = sha256(abi.encode(_leafs[j], _leafs[j + 1]));
      }
    }

    return _leafs[0];
  }
}
