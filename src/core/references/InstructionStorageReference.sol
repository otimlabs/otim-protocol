// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Constants} from "../../libraries/Constants.sol";
import {InstructionLib} from "../../libraries/Instruction.sol";

import {IInstructionStorage} from "../../core/interfaces/IInstructionStorage.sol";

/// @title InstructionStorageReference
/// @author Otim Labs, Inc.
/// @notice an external storage contract for storing Instruction execution state
contract InstructionStorageReference is IInstructionStorage {
    /// @notice the Instruction execution state of each Instruction for each user
    mapping(address => mapping(bytes32 => InstructionLib.ExecutionState)) private _stateMap;
    /// @notice hash of the "delegation designator" i.e. keccak256(0xef0100 || delegate_address)
    bytes32 public immutable designatorHash;

    /// @notice ensures the call is coming from a delegated EOA AND from the contract code,
    ///         not directly from the EOA
    modifier fromDelegateCodeOnly() {
        if (address(msg.sender).codehash != designatorHash || tx.origin == msg.sender) {
            revert DataCorruptionAttempted();
        }
        _;
    }

    constructor() {
        // construct the "delegation designator", then hash it.
        // OtimDelegate will deploy this contract so msg.sender will be the address of the delegate contract
        designatorHash = keccak256(abi.encodePacked(Constants.EIP7702_PREFIX, msg.sender));
    }

    /// @inheritdoc IInstructionStorage
    function incrementExecutionCounter(bytes32 instructionId) external fromDelegateCodeOnly {
        _stateMap[msg.sender][instructionId].executionCount++;
        _stateMap[msg.sender][instructionId].lastExecuted = uint120(block.timestamp);
    }

    /// @inheritdoc IInstructionStorage
    function incrementAndDeactivate(bytes32 instructionId) external fromDelegateCodeOnly {
        _stateMap[msg.sender][instructionId].deactivated = true;
        _stateMap[msg.sender][instructionId].executionCount++;
        _stateMap[msg.sender][instructionId].lastExecuted = uint120(block.timestamp);
    }

    /// @inheritdoc IInstructionStorage
    function deactivateStorage(bytes32 instructionId) external fromDelegateCodeOnly {
        _stateMap[msg.sender][instructionId].deactivated = true;
    }

    /// @inheritdoc IInstructionStorage
    function getExecutionState(address user, bytes32 instructionId)
        external
        view
        returns (InstructionLib.ExecutionState memory)
    {
        return _stateMap[user][instructionId];
    }

    /// @inheritdoc IInstructionStorage
    function getExecutionState(bytes32 instructionId) external view returns (InstructionLib.ExecutionState memory) {
        return _stateMap[msg.sender][instructionId];
    }

    /// @inheritdoc IInstructionStorage
    function isDeactivated(bytes32 instructionId) external view returns (bool) {
        return _stateMap[msg.sender][instructionId].deactivated;
    }
}
