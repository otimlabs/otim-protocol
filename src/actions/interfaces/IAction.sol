// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {InstructionLib} from "../../libraries/Instruction.sol";

/// @title IAction
/// @author Otim Labs, Inc.
/// @notice interface for Action contracts
interface IAction {
    /// @notice returns the EIP-712 type hash for the Action-specific Instruction and the EIP-712 hash of the Action-specific Instruction arguments
    /// @param arguments - encoded Instruction arguments
    /// @return instructionTypeHash - EIP-712 type hash for the Action-specific Instruction
    /// @return argumentsTypeHash - EIP-712 hash of the Action-specific Instruction arguments
    function argumentsHash(bytes calldata arguments) external returns (bytes32, bytes32);

    /// @notice execute Action logic with Instruction arguments
    /// @param instruction - Instruction
    /// @param signature - Signature over the Instruction signing hash
    /// @param executionState - ExecutionState
    /// @return deactivate - whether the Instruction should be automatically deactivated
    function execute(
        InstructionLib.Instruction calldata instruction,
        InstructionLib.Signature calldata signature,
        InstructionLib.ExecutionState calldata executionState
    ) external returns (bool);
}
