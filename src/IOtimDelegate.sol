// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC165} from "@openzeppelin-contracts/utils/introspection/IERC165.sol";
import {IERC721Receiver} from "@openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC1271} from "@openzeppelin-contracts/interfaces/IERC1271.sol";

import {IGateway} from "./core/interfaces/IGateway.sol";
import {IInstructionStorage} from "./core/interfaces/IInstructionStorage.sol";
import {IActionManager} from "./core/interfaces/IActionManager.sol";

import {InstructionLib} from "./libraries/Instruction.sol";

/// @title IOtimDelegate
/// @author Otim Labs, Inc.
/// @notice interface for OtimDelegate contract
interface IOtimDelegate is IERC165, IERC721Receiver, IERC1155Receiver, IERC1271 {
    /// @notice emitted when an Instruction is executed on behalf of a user
    event InstructionExecuted(bytes32 indexed instructionId, uint256 executionCount);
    /// @notice emitted when an Instruction is deactivated by the user before its natural completion
    event InstructionDeactivated(bytes32 indexed instructionId);

    error InvalidSignature(bytes32 instructionId);
    error ActionNotExecutable(bytes32 instructionId);
    error ActionExecutionFailed(bytes32 instructionId, bytes result);
    error ExecutionSameBlock(bytes32 instructionId);
    error InstructionAlreadyDeactivated(bytes32 instructionId);

    function gateway() external view returns (IGateway);
    function instructionStorage() external view returns (IInstructionStorage);
    function actionManager() external view returns (IActionManager);

    /// @notice execute an Instruction
    /// @dev the first execution "activates" the Instruction, subsequent calls ignore signature
    /// @param instruction - a conditional or scheduled recurring task to be carried out on behalf of the user
    /// @param signature - user signature over the Instruction activation hash
    function executeInstruction(
        InstructionLib.Instruction calldata instruction,
        InstructionLib.Signature calldata signature
    ) external;

    /// @notice deactivate an Instruction
    /// @param deactivation - a InstructionDeactivation struct
    /// @param signature - user signature over the Instruction deactivation hash
    function deactivateInstruction(
        InstructionLib.InstructionDeactivation calldata deactivation,
        InstructionLib.Signature calldata signature
    ) external;
}
