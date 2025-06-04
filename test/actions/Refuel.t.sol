// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {InstructionTestContext} from "../utils/InstructionTestContext.sol";
import {RevertTarget} from "../mocks/RevertTarget.sol";
import {DrainGasTarget} from "../mocks/DrainGasTarget.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";
import {IInstructionStorage} from "../../src/core/interfaces/IInstructionStorage.sol";
import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {IRefuelAction} from "../../src/actions/interfaces/IRefuelAction.sol";
import {RefuelAction} from "../../src/actions/RefuelAction.sol";

import "../../src/actions/errors/Errors.sol";

contract RefuelTest is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

    RefuelAction public refuel = new RefuelAction(address(0), address(0), 0);

    /// @notice test Refuel target
    VmSafe.Wallet public target = vm.createWallet("target");

    /// @notice user and target starting balances
    uint256 public TARGET_START_BALANCE = 50;

    /// @notice default Action arguments
    address payable public DEFAULT_TARGET = payable(target.addr);
    uint256 public DEFAULT_THRESHOLD = 2 gwei;
    uint256 public DEFAULT_END_BALANCE = 5 gwei;
    uint256 public DEFAULT_GAS_LIMIT = 21_000;

    IOtimFee.Fee public DEFAULT_FEE;

    /// @notice default Action arguments
    IRefuelAction.Refuel public DEFAULT_ACTION_ARGS = IRefuelAction.Refuel({
        target: DEFAULT_TARGET,
        threshold: DEFAULT_THRESHOLD,
        endBalance: DEFAULT_END_BALANCE,
        gasLimit: DEFAULT_GAS_LIMIT,
        fee: DEFAULT_FEE
    });

    constructor() {
        /// @notice Action setup
        actionManager.addAction(address(refuel));

        vm.deal(target.addr, TARGET_START_BALANCE);

        /// @notice Instruction defaults
        DEFAULT_ACTION = address(refuel);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical Refuel flow
    function test_refuel_happyPath() public {
        vm.pauseGasMetering();

        buildInstruction();

        assertEq(address(user).balance, USER_START_BALANCE);
        assertEq(target.addr.balance, TARGET_START_BALANCE);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(address(user).balance, USER_START_BALANCE - (DEFAULT_END_BALANCE - TARGET_START_BALANCE));
        assertEq(target.addr.balance, DEFAULT_END_BALANCE);
    }

    /// @notice typical Refuel flow with threshold == 0
    function test_refuel_happyPath_thresholdZero() public {
        vm.pauseGasMetering();

        // keep defaults but set threshold to 0
        DEFAULT_ACTION_ARGS.threshold = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.deal(target.addr, 0);

        assertEq(address(user).balance, USER_START_BALANCE);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(address(user).balance, USER_START_BALANCE - DEFAULT_END_BALANCE);
        assertEq(target.addr.balance, DEFAULT_END_BALANCE);
    }

    /// @notice test validation reverts with target == address(0)
    function test_refuel_targetZero() public {
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

    /// @notice test that validation fails with threshold above endBalance
    function test_refuel_thresholdAboveEndBalance() public {
        vm.pauseGasMetering();

        // keep defaults but set threshold to endBalance + 1
        DEFAULT_ACTION_ARGS.threshold = DEFAULT_END_BALANCE + 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with threshold == endBalance
    function test_refuel_thresholdEqualsEndBalance() public {
        vm.pauseGasMetering();

        // keep defaults but set threshold to endBalance
        DEFAULT_ACTION_ARGS.threshold = DEFAULT_END_BALANCE;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with ETH balance over threshold
    function test_refuel_balanceOverThreshold() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.deal(target.addr, DEFAULT_THRESHOLD + 1);

        bytes memory result = abi.encodeWithSelector(BalanceOverThreshold.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with ETH insufficient balance
    function test_refuel_insufficientBalance() public {
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
    function test_refuel_targetRevert() public {
        vm.pauseGasMetering();

        // keep defaults but set target to RevertTarget
        DEFAULT_ACTION_ARGS.target = payable(address(new RevertTarget()));

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit IRefuelAction.RefuelActionFailed(DEFAULT_ACTION_ARGS.target);

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
    function test_refuel_targetDrainGas() public {
        vm.pauseGasMetering();

        // keep defaults but set target to DrainGasTarget
        DEFAULT_ACTION_ARGS.target = payable(address(new DrainGasTarget()));

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit IRefuelAction.RefuelActionFailed(DEFAULT_ACTION_ARGS.target);

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
