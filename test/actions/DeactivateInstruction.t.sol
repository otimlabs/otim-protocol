// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {VmSafe} from "forge-std/src/Vm.sol";

import {InstructionTestContext} from "../utils/InstructionTestContext.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {IInterval} from "../../src/actions/schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {IDeactivateInstructionAction} from "../../src/actions/interfaces/IDeactivateInstructionAction.sol";
import {DeactivateInstructionAction} from "../../src/actions/DeactivateInstructionAction.sol";

import {ITransferAction} from "../../src/actions/interfaces/ITransferAction.sol";
import {TransferAction} from "../../src/actions/TransferAction.sol";

import "../../src/actions/errors/Errors.sol";

contract DeactivateInstruction is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

    TransferAction public transfer;
    DeactivateInstructionAction public deactivate;

    /// @notice test Transfer target
    VmSafe.Wallet public target = vm.createWallet("target");

    IInterval.Schedule public DEFAULT_SCHEDULE;
    IOtimFee.Fee public DEFAULT_FEE;

    ITransferAction.Transfer public DEFAULT_TRANSFER_ARGS;

    bytes32 public DEFAULT_INSTRUCTION_ID = bytes32(uint256(1));

    IDeactivateInstructionAction.DeactivateInstruction public DEFAULT_ACTION_ARGS;

    constructor() {
        transfer = new TransferAction(address(0), address(0), 0);
        deactivate = new DeactivateInstructionAction(address(instructionStorage), address(0), address(0), 0);

        /// @notice Action setup
        actionManager.addAction(address(transfer));
        actionManager.addAction(address(deactivate));

        DEFAULT_SCHEDULE = IInterval.Schedule({startAt: 0, startBy: 0, interval: 1, timeout: 0});

        DEFAULT_TRANSFER_ARGS = ITransferAction.Transfer({
            target: payable(target.addr),
            value: 100,
            gasLimit: 0,
            schedule: DEFAULT_SCHEDULE,
            fee: DEFAULT_FEE
        });

        DEFAULT_ACTION_ARGS = IDeactivateInstructionAction.DeactivateInstruction({
            instructionId: DEFAULT_INSTRUCTION_ID,
            fee: DEFAULT_FEE
        });

        /// @notice Instruction defaults
        DEFAULT_MAX_EXECUTIONS = 1;
        DEFAULT_ACTION = address(deactivate);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical DeactivateInstruction flow
    function test_deactivateInstruction_happyPath() public {
        // execute transfer instruction

        buildInstruction(DEFAULT_SALT, 0, address(transfer), abi.encode(DEFAULT_TRANSFER_ARGS));

        bytes32 transferInstructionId = instructionId;

        user.executeInstruction(instruction, instructionSig);

        // execute deactivate instruction

        DEFAULT_ACTION_ARGS.instructionId = transferInstructionId;
        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, address(deactivate), abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit IOtimDelegate.InstructionDeactivated(transferInstructionId);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the transfer instruction was deactivated
        InstructionLib.ExecutionState memory executionState =
            instructionStorage.getExecutionState(address(user), transferInstructionId);

        assertTrue(executionState.deactivated);
    }

    /// @notice typical DeactivateInstruction flow before activation
    function test_deactivateInstruction_happyPath_beforeActivation() public {
        // execute deactivate instruction

        buildInstruction();

        vm.expectEmit();
        emit IOtimDelegate.InstructionDeactivated(DEFAULT_ACTION_ARGS.instructionId);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the instruction was deactivated

        InstructionLib.ExecutionState memory executionState =
            instructionStorage.getExecutionState(address(user), DEFAULT_ACTION_ARGS.instructionId);

        assertTrue(executionState.deactivated);
    }

    /// @notice test that execution fails with maxExecutions > 1
    function test_deactivateInstruction_maxExecutionsTooHigh() public {
        buildInstruction(DEFAULT_SALT, 2, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails with maxExecutions = 0
    function test_deactivateInstruction_maxExecutionsZero() public {
        buildInstruction(DEFAULT_SALT, 0, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails with instructionId = bytes32(0)
    function test_deactivateInstruction_instructionIdZero() public {
        DEFAULT_ACTION_ARGS.instructionId = bytes32(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails if the instruction is already deactivated
    function test_deactivateInstruction_alreadyDeactivated() public {
        buildInstruction();

        vm.expectEmit();
        emit IOtimDelegate.InstructionDeactivated(DEFAULT_ACTION_ARGS.instructionId);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        user.executeInstruction(instruction, instructionSig);

        // try to deactivate the same instruction again (new salt to avoid clash with previous instruction since maxExecutions must be 1)

        buildInstruction(1, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InstructionAlreadyDeactivated.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
