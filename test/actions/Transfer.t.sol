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

import {ITransferAction} from "../../src/actions/interfaces/ITransferAction.sol";
import {TransferAction} from "../../src/actions/TransferAction.sol";

import "../../src/actions/errors/Errors.sol";

contract TransferTest is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

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

    ITransferAction.Transfer public DEFAULT_ACTION_ARGS;

    constructor() {
        /// @notice Action setup
        actionManager.addAction(address(transfer));

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

        DEFAULT_ACTION_ARGS = ITransferAction.Transfer({
            target: DEFAULT_TARGET,
            value: DEFAULT_VALUE,
            gasLimit: DEFAULT_GAS_LIMIT,
            schedule: DEFAULT_SCHEDULE,
            fee: DEFAULT_FEE
        });

        /// @notice Instruction defaults
        DEFAULT_ACTION = address(transfer);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical Transfer flow
    function test_transfer_happyPath() public {
        vm.pauseGasMetering();

        buildInstruction();

        assertEq(address(user).balance, USER_START_BALANCE);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(address(user).balance, USER_START_BALANCE - DEFAULT_VALUE);
        assertEq(target.addr.balance, DEFAULT_VALUE);
    }

    /// @notice test that validation fails with target == address(0)
    function test_transfer_targetZero() public {
        vm.pauseGasMetering();

        // keep defaults but set target to address(0)
        DEFAULT_ACTION_ARGS.target = payable(address(0));

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with zero value
    function test_transfer_valueZero() public {
        vm.pauseGasMetering();

        // keep defaults but set value to 0
        DEFAULT_ACTION_ARGS.value = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with user insufficient balance
    function test_transfer_insufficientBalance() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.deal(address(user), 0);

        bytes memory result = abi.encodeWithSelector(InsufficientBalance.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction is automatically deactivated when the action fails from the target reverting
    function test_transfer_targetRevert() public {
        vm.pauseGasMetering();

        // keep defaults but set target to badTarget
        DEFAULT_ACTION_ARGS.target = payable(new RevertTarget());

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit ITransferAction.TransferActionFailed(DEFAULT_ACTION_ARGS.target);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the instruction was deactivated

        IInstructionStorage instructionStorage = delegate.instructionStorage();

        InstructionLib.ExecutionState memory executionState =
            instructionStorage.getExecutionState(address(user), instructionId);

        assertTrue(executionState.deactivated);
        assertEq(executionState.executionCount, 0);
        assertEq(executionState.lastExecuted, 0);
    }

    /// @notice test that the Instruction is automatically deactivated when the action fails from the target draining gas
    function test_transfer_targetDrainGas() public {
        vm.pauseGasMetering();

        // keep defaults but set target to DrainGasTarget
        DEFAULT_ACTION_ARGS.target = payable(new DrainGasTarget());

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit ITransferAction.TransferActionFailed(DEFAULT_ACTION_ARGS.target);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the instruction was deactivated

        IInstructionStorage instructionStorage = delegate.instructionStorage();

        InstructionLib.ExecutionState memory executionState =
            instructionStorage.getExecutionState(address(user), instructionId);

        assertTrue(executionState.deactivated);
        assertEq(executionState.executionCount, 0);
        assertEq(executionState.lastExecuted, 0);
    }
}
