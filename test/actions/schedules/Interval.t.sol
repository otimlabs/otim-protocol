// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {InstructionTestContext} from "../../utils/InstructionTestContext.sol";

import {InstructionLib} from "../../../src/libraries/Instruction.sol";

import {IOtimDelegate} from "../../../src/IOtimDelegate.sol";

import {IInterval} from "../../../src/actions/schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {ITransferAction} from "../../../src/actions/interfaces/ITransferAction.sol";
import {TransferAction} from "../../../src/actions/TransferAction.sol";

import "../../../src/actions/errors/Errors.sol";

contract IntervalTest is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

    TransferAction public transfer = new TransferAction(address(0), address(0), 0);

    /// @notice test Transfer target
    VmSafe.Wallet public target = vm.createWallet("target");

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

    /// @notice test that execution fails before startAt timestamp
    function test_checkStart_tooEarly() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.warp(DEFAULT_START_AT - 1);

        bytes memory result = abi.encodeWithSelector(IInterval.ExecutionTooEarly.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails after startBy timestamp
    function test_checkStart_tooLate() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.warp(DEFAULT_START_BY + 1);

        bytes memory result = abi.encodeWithSelector(IInterval.ExecutionTooLate.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails before interval
    function test_checkInterval_tooEarly() public {
        vm.pauseGasMetering();

        buildInstruction();

        user.executeInstruction(instruction, instructionSig);

        skip(DEFAULT_INTERVAL - 1);

        bytes memory result = abi.encodeWithSelector(IInterval.ExecutionTooEarly.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails after timeout
    function test_checkInterval_tooLate() public {
        vm.pauseGasMetering();

        buildInstruction();

        user.executeInstruction(instruction, instructionSig);

        skip(DEFAULT_INTERVAL + DEFAULT_TIMEOUT + 1);

        bytes memory result = abi.encodeWithSelector(IInterval.ExecutionTooLate.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that Instruction startBy is not enforced when startBy = 0
    function test_checkStart_startByZero(uint64 timestamp) public {
        vm.pauseGasMetering();

        vm.assume(timestamp > DEFAULT_START_AT && timestamp < type(uint64).max - DEFAULT_INTERVAL - 1);
        vm.warp(timestamp);

        // keep defaults but set startBy to 0
        DEFAULT_ACTION_ARGS.schedule.startBy = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // show that the schedule starts at the initial timestamp as expected

        skip(DEFAULT_INTERVAL);

        // should revert because the interval has not passed
        bytes memory result = abi.encodeWithSelector(IInterval.ExecutionTooEarly.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        user.executeInstruction(instruction, instructionSig);

        skip(1);

        // should succeed because the interval has now passed
        user.executeInstruction(instruction, instructionSig);
    }

    /// @notice test that Instruction timeout is not enforced when timeout = 0
    function test_checkStart_timeoutZero(uint64 skipSeconds) public {
        vm.pauseGasMetering();

        vm.assume(skipSeconds > 0 && skipSeconds < type(uint64).max - DEFAULT_INTERVAL);

        // keep defaults but set timeout to 0
        DEFAULT_ACTION_ARGS.schedule.timeout = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // show that execution can happen anytime after the interval when timeout = 0

        skip(DEFAULT_INTERVAL + skipSeconds);

        user.executeInstruction(instruction, instructionSig);
    }
}
