// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {InstructionLib} from "../../libraries/Instruction.sol";

/// @title IInstructionStorage
/// @author Otim Labs, Inc.
/// @notice interface for InstructionStorage contract
interface IInstructionStorage {
    error DataCorruptionAttempted();

    /// @notice increments the execution counter for an Instruction and sets `lastExecuted` to current block.timestamp
    /// @param instructionId - unique identifier for an Instruction
    function incrementExecutionCounter(bytes32 instructionId) external;

    /// @notice increments the execution counter for an Instruction, sets `lastExecuted` to current block.timestamp, and deactivates
    /// @param instructionId - unique identifier for an Instruction
    function incrementAndDeactivate(bytes32 instructionId) external;

    /// @notice deactivates an Instruction's execution state in storage
    /// @param instructionId - unique identifier for an Instruction
    function deactivateStorage(bytes32 instructionId) external;

    /// @notice returns the execution state of an Instruction for a particular user
    /// @param user - the user the Instruction pertains to
    /// @param instructionId - unique identifier for an Instruction
    /// @return executionState - the current execution state of the Instruction
    function getExecutionState(address user, bytes32 instructionId)
        external
        view
        returns (InstructionLib.ExecutionState memory);

    /// @notice returns the execution state of an Instruction for msg.sender
    /// @param instructionId - unique identifier for an Instruction
    /// @return executionState - the current execution state of the Instruction
    function getExecutionState(bytes32 instructionId) external view returns (InstructionLib.ExecutionState memory);

    /// @notice checks if an Instruction is deactivated for msg.sender
    /// @param instructionId - unique identifier for an Instruction
    /// @return deactivated - true if the Instruction is deactivated
    function isDeactivated(bytes32 instructionId) external view returns (bool);
}
