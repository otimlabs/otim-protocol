// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,DeactivateInstruction deactivateInstruction)DeactivateInstruction(bytes32 instructionId,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "DeactivateInstruction(bytes32 instructionId,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title IDeactivateInstructionAction
/// @author Otim Labs, Inc.
/// @notice interface for DeactivateInstructionAction contract
interface IDeactivateInstructionAction is IOtimFee {
    /// @notice arguments for the DeactivateInstructionAction contract
    /// @param instructionId - the instructionId of the instruction to deactivate
    /// @param fee - the fee Otim will charge for the deactivation
    struct DeactivateInstruction {
        bytes32 instructionId;
        Fee fee;
    }

    /// @notice calculates the EIP-712 hash of the DeactivateInstruction struct
    function hash(DeactivateInstruction memory arguments) external pure returns (bytes32);
}
