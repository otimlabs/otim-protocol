// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {VmSafe} from "forge-std/src/Vm.sol";

import {InstructionTestContext} from "../utils/InstructionTestContext.sol";
import {RevertTarget} from "../mocks/RevertTarget.sol";
import {DrainGasTarget} from "../mocks/DrainGasTarget.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";
import {IInstructionStorage} from "../../src/core/interfaces/IInstructionStorage.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {ITransferOnceAction} from "../../src/actions/interfaces/ITransferOnceAction.sol";
import {TransferOnceAction} from "../../src/actions/TransferOnceAction.sol";

import "../../src/actions/errors/Errors.sol";

contract TransferOnceTest is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

    TransferOnceAction public transfer = new TransferOnceAction(address(0), address(0), 0);

    /// @notice test Transfer target
    VmSafe.Wallet public target = vm.createWallet("target");

    /// @notice default Action arguments
    address payable public DEFAULT_TARGET = payable(target.addr);
    uint256 public DEFAULT_VALUE = 100;
    uint256 public DEFAULT_GAS_LIMIT = 21_000;

    IOtimFee.Fee public DEFAULT_FEE;

    ITransferOnceAction.TransferOnce public DEFAULT_ACTION_ARGS;

    constructor() {
        /// @notice Action setup
        actionManager.addAction(address(transfer));

        DEFAULT_ACTION_ARGS = ITransferOnceAction.TransferOnce({
            target: DEFAULT_TARGET, value: DEFAULT_VALUE, gasLimit: DEFAULT_GAS_LIMIT, fee: DEFAULT_FEE
        });

        /// @notice Instruction defaults
        DEFAULT_MAX_EXECUTIONS = 1;
        DEFAULT_ACTION = address(transfer);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical TransferOnce flow
    function test_transferOnce_happyPath() public {
        buildInstruction();

        assertEq(address(user).balance, USER_START_BALANCE);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(address(user).balance, USER_START_BALANCE - DEFAULT_VALUE);
        assertEq(target.addr.balance, DEFAULT_VALUE);
    }

    /// @notice test that execution fails with maxExecutions > 1
    function test_transferOnce_maxExecutionsTooHigh() public {
        buildInstruction(DEFAULT_SALT, 2, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails with maxExecutions = 0
    function test_transferOnce_maxExecutionsZero() public {
        buildInstruction(DEFAULT_SALT, 0, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with target == address(0)
    function test_transferOnce_targetZero() public {
        // keep defaults but set target to address(0)
        DEFAULT_ACTION_ARGS.target = payable(address(0));

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with zero value
    function test_transferOnce_valueZero() public {
        // keep defaults but set value to 0
        DEFAULT_ACTION_ARGS.value = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with user insufficient balance
    function test_transferOnce_insufficientBalance() public {
        buildInstruction();

        vm.deal(address(user), 0);

        bytes memory result = abi.encodeWithSelector(InsufficientBalance.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction is automatically deactivated when the action fails from the target reverting
    function test_transferOnce_targetRevert() public {
        // keep defaults but set target to badTarget
        DEFAULT_ACTION_ARGS.target = payable(new RevertTarget());

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit ITransferOnceAction.TransferOnceActionFailed(DEFAULT_ACTION_ARGS.target);

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
    function test_transferOnce_targetDrainGas() public {
        // keep defaults but set target to DrainGasTarget
        DEFAULT_ACTION_ARGS.target = payable(new DrainGasTarget());

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit ITransferOnceAction.TransferOnceActionFailed(DEFAULT_ACTION_ARGS.target);

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
