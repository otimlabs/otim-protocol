// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {InstructionLib} from "../libraries/Instruction.sol";

import {IOtimDelegate} from "../IOtimDelegate.sol";
import {IInstructionStorage} from "../core/interfaces/IInstructionStorage.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {
    IDeactivateInstructionAction,
    INSTRUCTION_TYPEHASH,
    ARGUMENTS_TYPEHASH
} from "./interfaces/IDeactivateInstructionAction.sol";

import {InvalidArguments, InstructionAlreadyDeactivated} from "./errors/Errors.sol";

/// @title DeactivateInstructionAction
/// @author Otim Labs, Inc.
/// @notice an Action that deactivates an existing instruction and charges a fee
contract DeactivateInstructionAction is IAction, IDeactivateInstructionAction, OtimFee {
    using InstructionLib for InstructionLib.Instruction;

    /// @notice the InstructionStorage contract
    IInstructionStorage public immutable instructionStorage;

    constructor(
        address instructionStorageAddress,
        address feeTokenRegistryAddress,
        address treasuryAddress,
        uint256 gasConstant_
    ) OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_) {
        instructionStorage = IInstructionStorage(instructionStorageAddress);
    }

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (DeactivateInstruction))));
    }

    /// @inheritdoc IDeactivateInstructionAction
    function hash(DeactivateInstruction memory arguments) public pure returns (bytes32) {
        return keccak256(abi.encode(ARGUMENTS_TYPEHASH, arguments.instructionId, hash(arguments.fee)));
    }

    /// @inheritdoc IAction
    function execute(
        InstructionLib.Instruction calldata instruction,
        InstructionLib.Signature calldata,
        InstructionLib.ExecutionState calldata
    ) external override returns (bool) {
        // initial gas measurement for fee calculation
        uint256 startGas = gasleft();

        // decode the arguments from the instruction
        DeactivateInstruction memory arguments = abi.decode(instruction.arguments, (DeactivateInstruction));

        // check if arguments are valid
        if (instruction.maxExecutions != 1 || arguments.instructionId == bytes32(0)) {
            revert InvalidArguments();
        }

        // check if the instruction is already deactivated
        if (instructionStorage.isDeactivated(arguments.instructionId)) {
            revert InstructionAlreadyDeactivated();
        }

        // deactivate the instruction
        // slither-disable-next-line reentrancy-events
        instructionStorage.deactivateStorage(arguments.instructionId);

        // emit that the instruction has been deactivated
        emit IOtimDelegate.InstructionDeactivated(arguments.instructionId);

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        return false;
    }
}
