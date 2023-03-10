// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.18;

import {Test} from "forge-std/Test.sol";

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
 *  | 0x00                     | 0x04       | rollup block number
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
 *  | 0xb8                     | 0x04       | endPrivateDataTreeSnapshot.nextAvailableLeafIndex
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
contract Decoder is Test {
    /**
     * @notice Decodes the inputs and computes values to check state against
     * @param _inputData - The inputs of the rollup block.
     * @return rollupBlockNumber  - The Rollup block number.
     * @return oldStateHash - The state hash expected prior the execution.
     * @return newStateHash - The state hash expected after the execution.
     * @return publicInputHash - The hash of the public inputs
     */
    function _decode(
        bytes memory _inputData
    )
        internal
        view
        returns (
            uint256 rollupBlockNumber,
            bytes32 oldStateHash,
            bytes32 newStateHash,
            bytes32 publicInputHash
        )
    {
        rollupBlockNumber = _getRollupBlockNumber(_inputData);
        oldStateHash = _computeStateHash(
            rollupBlockNumber - 1,
            0x4,
            _inputData
        );
        newStateHash = _computeStateHash(rollupBlockNumber, 0xb8, _inputData);
        publicInputHash = _computePublicInputsHash(_inputData);
    }

    /**
     * Computes a hash of the public inputs from the calldata
     * @param _inputData - The rollup block calldata.
     * @return sha256(header[:0x16c], newCommitmentHash, newNullifierHash, contractHash, contractDataHash)
     */
    function _computePublicInputsHash(
        bytes memory _inputData
    ) internal view returns (bytes32) {
        (
            uint256 commitmentCount,
            bytes32 newCommitmentHash
        ) = _computeCommitmentsOrNullifierRoot(_inputData, 0x16c);
        // emit log_named_uint("commitmentCount", commitmentCount);
        // emit log_named_bytes32("newCommitmentHash", newCommitmentHash);

        (
            uint256 nullifierCount,
            bytes32 newNullifierHash
        ) = _computeCommitmentsOrNullifierRoot(
                _inputData,
                0x170 + commitmentCount * 0x20
            );
        // emit log_named_uint("nullifierCount", nullifierCount);
        // emit log_named_bytes32("newNullifierHash", newNullifierHash);

        (uint256 contractCount, bytes32 contractHash) = _computeContractsRoot(
            _inputData,
            0x174 + (commitmentCount + nullifierCount) * 0x20
        );
        // emit log_named_uint("contractCount", contractCount);
        // emit log_named_bytes32("contractHash", contractHash);

        bytes32 contractDataHash = _computeContractsDataRoot(
            _inputData,
            0x174 + (commitmentCount + nullifierCount + contractCount) * 0x20,
            contractCount
        );
        // emit log_named_bytes32("contractDataHash", contractDataHash);

        // Compute the public inputs hash

        uint256 size = 0x16c + 0x20 * 4;
        bytes memory temp = new bytes(size);
        assembly {
            pop(
                staticcall(
                    gas(),
                    0x4,
                    add(_inputData, 0x20),
                    size,
                    add(temp, 0x20),
                    size
                )
            )
        }

        // Overwrite the last 4 words
        uint256 offset = 0x16c + 0x20;
        assembly {
            mstore(add(temp, offset), newNullifierHash)
            offset := add(offset, 0x20)
            mstore(add(temp, offset), newCommitmentHash)
            offset := add(offset, 0x20)
            mstore(add(temp, offset), contractHash)
            offset := add(offset, 0x20)
            mstore(add(temp, offset), contractDataHash)
            offset := add(offset, 0x20)
        }

        return sha256(temp);
    }

    /**
     * @notice Extract the rollup block number from the inputs
     * @param _inputData - The rollup block calldata
     * @return rollupBlockNumber - The blocknumber
     */
    function _getRollupBlockNumber(
        bytes memory _inputData
    ) internal pure returns (uint256 rollupBlockNumber) {
        assembly {
            rollupBlockNumber := and(
                shr(224, mload(add(_inputData, 0x20))),
                0xffffffff
            )
        }
    }

    /**
     * @notice Computes a state hash
     * @param _rollupBlockNumber - The rollup block number
     * @param _offset - The offset into the data, 0x04 for old, 0xb8 for next
     * @param _inputData - The calldata for the rollup block
     * @return The state hash
     */
    function _computeStateHash(
        uint256 _rollupBlockNumber,
        uint256 _offset,
        bytes memory _inputData
    ) internal view returns (bytes32) {
        bytes memory temp = new bytes(0xb8);

        assembly {
            mstore8(add(temp, 0x20), shr(24, _rollupBlockNumber))
            mstore8(add(temp, 0x21), shr(16, _rollupBlockNumber))
            mstore8(add(temp, 0x22), shr(8, _rollupBlockNumber))
            mstore8(add(temp, 0x23), _rollupBlockNumber)
        }
        assembly {
            pop(
                staticcall(
                    gas(),
                    0x4,
                    add(_inputData, add(0x20, _offset)),
                    0xb4,
                    add(temp, 0x24),
                    0xb4
                )
            )
        }

        return sha256(temp);
    }

    /**
     * @notice Computes a root of a commitment or nullifier subtree
     * @param _inputData - The raw input bytes as specified above.
     * @param _offset - The offset to land at "len(newCommits)" or "len(newNullifiers)"
     */
    function _computeCommitmentsOrNullifierRoot(
        bytes memory _inputData,
        uint256 _offset
    ) internal view returns (uint256 size, bytes32) {
        uint256 elementsPerLeaf = 8;
        assembly {
            size := and(
                shr(224, mload(add(_inputData, add(_offset, 0x20)))),
                0xffffffff
            )
        }

        // Compute the leafs. Each leaf is 8 elements
        bytes32[] memory leafs = new bytes32[](size / elementsPerLeaf);
        for (uint256 i = 0; i < size / elementsPerLeaf; i++) {
            uint256 src = 0x04 + 0x20 + _offset + i * 8 * 0x20;
            bytes memory inputValue = new bytes(0x100);
            // inputValue = _inputData[src:src+256]
            assembly {
                pop(
                    staticcall(
                        gas(),
                        0x4,
                        add(_inputData, src),
                        0x100,
                        add(inputValue, 0x20),
                        0x100
                    )
                )
            }
            leafs[i] = sha256(inputValue);
        }

        bytes32 root = _computeRoot(leafs);

        return (size, root);
    }

    /**
     * @notice Computes the root for the contracts data tree.
     * @dev Two contracts elements are hashed together to get a leaf.
     * @param _inputData - The rollup block calldata.
     * @param _offset - The offset to where the contracts data begins
     * @return size - The number of elements in the contracts leaf list
     * @return The root of the contracts tree
     */
    function _computeContractsRoot(
        bytes memory _inputData,
        uint256 _offset
    ) internal view returns (uint256 size, bytes32) {
        uint256 elementsPerLeaf = 2;
        assembly {
            size := and(
                shr(224, mload(add(_inputData, add(_offset, 0x20)))),
                0xffffffff
            )
        }
        bytes32[] memory leafs = new bytes32[](size / elementsPerLeaf);
        for (uint256 i = 0; i < size / elementsPerLeaf; i++) {
            uint256 src = 0x04 + 0x20 + _offset + i * 0x40;
            bytes memory inputValue = new bytes(0x40);
            // inputValue = _inputData[src:src+64]
            assembly {
                pop(
                    staticcall(
                        gas(),
                        0x4,
                        add(_inputData, src),
                        0x40,
                        add(inputValue, 0x20),
                        0x40
                    )
                )
            }
            leafs[i] = sha256(inputValue);
        }

        return (size, _computeRoot(leafs));
    }

    /**
     * @notice Computes the root for the contracts data tree.
     * @dev Two contracts data elements are hashed together to get a leaf.
     * @param _inputData - The rollup block calldata.
     * @param _offset - The offset to where the contracts data begins
     * @param _size - The number of elements in the contracts data list
     * @return The root of the contracts data tree
     */
    function _computeContractsDataRoot(
        bytes memory _inputData,
        uint256 _offset,
        uint256 _size
    ) internal view returns (bytes32) {
        uint256 elementsPerLeaf = 2;
        bytes32[] memory leafs = new bytes32[](_size / elementsPerLeaf);
        for (uint256 i = 0; i < _size / elementsPerLeaf; i++) {
            uint256 src = 0x04 + 0x20 + _offset + i * 0x68;
            bytes memory inputValue = new bytes(0x68);
            // inputValue = _inputData[src:src+108]
            assembly {
                pop(
                    staticcall(
                        gas(),
                        0x4,
                        add(_inputData, src),
                        0x68,
                        add(inputValue, 0x20),
                        0x68
                    )
                )
            }
            leafs[i] = sha256(inputValue);
        }

        return _computeRoot(leafs);
    }

    /**
     * @notice Computes the root for a binary Merkle-tree given the leafs.
     * @dev Uses sha256.
     * @param _leafs - The 32 bytes leafs to build the tree of.
     * @return The root of the Merkle tree.
     */
    function _computeRoot(
        bytes32[] memory _leafs
    ) internal pure returns (bytes32) {
        // @todo Must pad the tree
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
