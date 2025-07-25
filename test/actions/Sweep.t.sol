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

import {ISweepAction} from "../../src/actions/interfaces/ISweepAction.sol";
import {SweepAction} from "../../src/actions/SweepAction.sol";

import "../../src/actions/errors/Errors.sol";

contract SweepTest is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

    SweepAction public sweep = new SweepAction(address(0), address(0), 0);

    /// @notice test Sweep target
    VmSafe.Wallet public target = vm.createWallet("target");

    /// @notice default Action arguments
    address payable public DEFAULT_TARGET = payable(target.addr);
    uint256 public DEFAULT_THRESHOLD = 5 gwei;
    uint256 public DEFAULT_END_BALANCE = 2 gwei;
    uint256 public DEFAULT_GAS_LIMIT = 0;

    IOtimFee.Fee public DEFAULT_FEE;

    /// @notice default Action arguments
    ISweepAction.Sweep public DEFAULT_ACTION_ARGS = ISweepAction.Sweep({
        target: DEFAULT_TARGET,
        threshold: DEFAULT_THRESHOLD,
        endBalance: DEFAULT_END_BALANCE,
        gasLimit: DEFAULT_GAS_LIMIT,
        fee: DEFAULT_FEE
    });

    constructor() {
        /// @notice Action setup
        actionManager.addAction(address(sweep));

        /// @notice Instruction defaults
        DEFAULT_ACTION = address(sweep);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical Sweep flow
    function test_sweep_happyPath() public {
        buildInstruction();

        assertEq(address(user).balance, USER_START_BALANCE);
        assertEq(target.addr.balance, 0);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(address(user).balance, DEFAULT_END_BALANCE);
        assertEq(target.addr.balance, USER_START_BALANCE - DEFAULT_END_BALANCE);
    }

    /// @notice test that execution succeeds with threshold == endBalance
    function test_sweep_happyPath_thresholdEqualsEndBalance() public {
        // keep defaults but set threshold == endBalance
        DEFAULT_ACTION_ARGS.threshold = DEFAULT_END_BALANCE;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        assertEq(address(user).balance, USER_START_BALANCE);
        assertEq(target.addr.balance, 0);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(address(user).balance, DEFAULT_END_BALANCE);
        assertEq(target.addr.balance, USER_START_BALANCE - DEFAULT_END_BALANCE);
    }

    /// @notice test that execution succeeds when balance is exactly equal to the threshold
    function test_sweep_happyPath_balanceEqualsThreshold() public {
        DEFAULT_ACTION_ARGS.threshold = USER_START_BALANCE;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        assertEq(address(user).balance, USER_START_BALANCE);
        assertEq(target.addr.balance, 0);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(address(user).balance, DEFAULT_END_BALANCE);
        assertEq(target.addr.balance, USER_START_BALANCE - DEFAULT_END_BALANCE);
    }

    /// @notice test execution reverts with target == address(0)
    function test_sweep_targetZero() public {
        // keep defaults but set target to address(0)
        DEFAULT_ACTION_ARGS.target = payable(address(0));

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails with endBalance above threshold
    function test_sweep_endBalanceAboveThreshold() public {
        // keep defaults but set endBalance above threshold
        DEFAULT_ACTION_ARGS.endBalance = DEFAULT_THRESHOLD + 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with ETH balance under threshold
    function test_sweep_balanceUnderThreshold() public {
        DEFAULT_ACTION_ARGS.threshold = USER_START_BALANCE + 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(BalanceUnderThreshold.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with ETH balance == endBalance
    /// @dev this is so the Instruction doesn't execute unnecessarily when the threshsold == endBalance
    function test_sweep_balanceEqualsEndBalance() public {
        vm.deal(address(user), DEFAULT_END_BALANCE);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(BalanceUnderThreshold.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with ETH balance equal to zero even if the threshold is zero
    /// @dev this is so the Instruction doesn't execute unnecessarily when the threshsold is zero
    /// @dev this is a special case of the above test case
    function test_sweep_balanceZero() public {
        DEFAULT_ACTION_ARGS.threshold = 0;
        DEFAULT_ACTION_ARGS.endBalance = 0;

        vm.deal(address(user), 0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(BalanceUnderThreshold.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction is automatically deactivated when the action fails from the target reverting
    function test_sweep_targetRevert() public {
        // keep defaults but set target to RevertTarget
        DEFAULT_ACTION_ARGS.target = payable(address(new RevertTarget()));

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit ISweepAction.SweepActionFailed(DEFAULT_ACTION_ARGS.target);

        vm.resetGasMetering();
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
    function test_sweep_targetDrainGas() public {
        // keep defaults but set target to DrainGasTarget
        DEFAULT_ACTION_ARGS.target = payable(address(new DrainGasTarget()));

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit ISweepAction.SweepActionFailed(DEFAULT_ACTION_ARGS.target);

        vm.resetGasMetering();
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
