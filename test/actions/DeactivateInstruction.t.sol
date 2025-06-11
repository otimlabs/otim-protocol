// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {InstructionTestContext} from "../utils/InstructionTestContext.sol";
import {RevertTarget} from "../mocks/RevertTarget.sol";
import {DrainGasTarget} from "../mocks/DrainGasTarget.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";
import {IInstructionStorage} from "../../src/core/interfaces/IInstructionStorage.sol";

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

    DeactivateInstructionAction public deactivate;

    TransferAction public transfer = new TransferAction(address(0), address(0), 0);

    /// @notice test Transfer target
    VmSafe.Wallet public target = vm.createWallet("target");

    /// @notice default Action arguments
    address payable public DEFAULT_TARGET = payable(target.addr);
    uint256 public DEFAULT_VALUE = 100;
    uint256 public DEFAULT_GAS_LIMIT = 21_000;

    uint256 DEFAULT_START_AT;
    uint256 DEFAULT_START_BY;
    uint256 DEFAULT_INTERVAL;
    uint256 DEFAULT_TIMEOUT;
    IInterval.Schedule public DEFAULT_SCHEDULE;

    IOtimFee.Fee public DEFAULT_FEE;

    ITransferAction.Transfer public DEFAULT_TRANSFER_ARGS;

    IDeactivateInstructionAction.DeactivateInstruction public DEFAULT_ACTION_ARGS;

    constructor() {
        deactivate = new DeactivateInstructionAction(address(instructionStorage), address(0), address(0), 0);

        /// @notice Action setup
        actionManager.addAction(address(transfer));
        actionManager.addAction(address(deactivate));

        /// @notice Schedule defaults
        DEFAULT_START_AT = block.timestamp - 1;
        DEFAULT_START_BY = block.timestamp + 10000;
        DEFAULT_INTERVAL = 36000;
        DEFAULT_TIMEOUT = 36000;
        DEFAULT_SCHEDULE = IInterval.Schedule({
            startAt: DEFAULT_START_AT,
            startBy: DEFAULT_START_BY,
            interval: DEFAULT_INTERVAL,
            timeout: DEFAULT_TIMEOUT
        });

        DEFAULT_TRANSFER_ARGS = ITransferAction.Transfer({
            target: DEFAULT_TARGET,
            value: DEFAULT_VALUE,
            gasLimit: DEFAULT_GAS_LIMIT,
            schedule: DEFAULT_SCHEDULE,
            fee: DEFAULT_FEE
        });

        /// @notice Instruction defaults
        DEFAULT_MAX_EXECUTIONS = 1;
        DEFAULT_ACTION = address(deactivate);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical DeactivateInstruction flow
    function test_deactivateInstruction_happyPath() public {
        vm.pauseGasMetering();

        // execute transfer instruction

        buildInstruction(DEFAULT_SALT, 2, address(transfer), abi.encode(DEFAULT_TRANSFER_ARGS));

        bytes32 transferInstructionId = instructionId;

        user.executeInstruction(instruction, instructionSig);

        // execute deactivate instruction

        DEFAULT_ACTION_ARGS.instructionId = transferInstructionId;
        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, address(deactivate), abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit IOtimDelegate.InstructionDeactivated(transferInstructionId);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the transfer instruction was deactivated

        InstructionLib.ExecutionState memory executionState =
            instructionStorage.getExecutionState(address(user), transferInstructionId);

        assertTrue(executionState.deactivated);
    }

    /// @notice typical DeactivateInstruction flow
    function test_deactivateInstruction_happyPath_beforeExecution() public {
        vm.pauseGasMetering();

        // execute deactivate instruction

        DEFAULT_ACTION_ARGS.instructionId = bytes32(uint256(1)); // dummy instructionId to deactivate
        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, address(deactivate), abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit IOtimDelegate.InstructionDeactivated(DEFAULT_ACTION_ARGS.instructionId);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the transfer instruction was deactivated

        InstructionLib.ExecutionState memory executionState =
            instructionStorage.getExecutionState(address(user), DEFAULT_ACTION_ARGS.instructionId);

        assertTrue(executionState.deactivated);
    }

    /// @notice test that execution fails with maxExecutions > 1
    function test_deactivateInstruction_maxExecutionsTooHigh() public {
        vm.pauseGasMetering();

        buildInstruction(DEFAULT_SALT, 2, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails with maxExecutions = 0
    function test_deactivateInstruction_maxExecutionsZero() public {
        vm.pauseGasMetering();

        buildInstruction(DEFAULT_SALT, 0, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails with instructionId = bytes32(0)
    function test_deactivateInstruction_instructionIdZero() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.instructionId = bytes32(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails if the instruction is already deactivated
    function test_deactivateInstruction_alreadyDeactivated() public {
        vm.pauseGasMetering();

        // dummy instructionId to deactivate
        DEFAULT_ACTION_ARGS.instructionId = bytes32(uint256(1));

        buildInstruction(0, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit IOtimDelegate.InstructionDeactivated(DEFAULT_ACTION_ARGS.instructionId);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        user.executeInstruction(instruction, instructionSig);

        // try to deactivate the same instruction again (new salt to avoid clash with previous instruction since maxExecutions must be 1)

        buildInstruction(1, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InstructionAlreadyDeactivated.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
