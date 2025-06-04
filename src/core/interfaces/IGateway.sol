// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {InstructionLib} from "../../libraries/Instruction.sol";

/// @title IGateway
/// @author Otim Labs, Inc.
/// @notice interface for the Gateway contract
interface IGateway {
    error TargetNotDelegated();

    /// @notice checks if the target address is delegated to OtimDelegate
    /// @param target - the target address to check
    /// @return delegated - if the target address is delegated to OtimDelegate
    function isDelegated(address target) external view returns (bool);

    /// @notice executes an Instruction on the target address if it is delegated to OtimDelegate
    /// @param target - the target account to execute the Instruction on
    /// @param instruction - the Instruction to execute
    /// @param signature - the Signature over the Instruction signing hash
    function safeExecuteInstruction(
        address target,
        InstructionLib.Instruction calldata instruction,
        InstructionLib.Signature calldata signature
    ) external;

    /// @notice executes an Instruction on the target address if it is delegated to OtimDelegate
    /// @dev After the first execution of an Instruction, the Signature is no longer checked, so we can omit the Signature in this case
    /// @param target - the target account to execute the Instruction on
    /// @param instruction - the Instruction to execute
    function safeExecuteInstruction(address target, InstructionLib.Instruction calldata instruction) external;

    /// @notice deactivates an Instruction on the target address if it is delegated to OtimDelegate
    /// @param target - the target account to deactivate the Instruction on
    /// @param deactivation - the InstructionDeactivation
    /// @param signature - the Signature over the InstructionDeactivation signing hash
    function safeDeactivateInstruction(
        address target,
        InstructionLib.InstructionDeactivation calldata deactivation,
        InstructionLib.Signature calldata signature
    ) external;
}
