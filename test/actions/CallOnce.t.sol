// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {ReentrancyGuardTransient} from "@openzeppelin-contracts/utils/ReentrancyGuardTransient.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";
import {InstructionTestContext} from "../utils/InstructionTestContext.sol";

import {MockTarget} from "../mocks/MockTarget.sol";

import {RevertTarget} from "../mocks/RevertTarget.sol";
import {ReturnBombTarget} from "../mocks/ReturnBombTarget.sol";
import {DrainGasTarget} from "../mocks/DrainGasTarget.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {ICallOnceAction} from "../../src/actions/interfaces/ICallOnceAction.sol";
import {CallOnceAction} from "../../src/actions/CallOnceAction.sol";

import "../../src/actions/errors/Errors.sol";

contract CallOnceTest is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

    CallOnceAction public callOnceAction = new CallOnceAction(address(instructionStorage), address(0), address(0), 0);

    MockTarget public target = new MockTarget();

    address public DEFAULT_TARGET = address(target);
    bool public DEFAULT_ALLOW_FAILURE;
    uint256 public DEFAULT_VALUE = 100;
    uint256 public DEFAULT_GAS_LIMIT = 2300;
    uint16 public DEFAULT_RETURN_SIZE_LIMIT = 512;
    bytes4 public DEFAULT_SELECTOR = target.helloWorldPayable.selector;
    bytes public DEFAULT_DATA = abi.encode("");

    IOtimFee.Fee public DEFAULT_FEE;

    ICallOnceAction.CallOnce public DEFAULT_ACTION_ARGS;

    constructor() {
        actionManager.addAction(address(callOnceAction));

        DEFAULT_ACTION_ARGS = ICallOnceAction.CallOnce({
            target: DEFAULT_TARGET,
            allowFailure: DEFAULT_ALLOW_FAILURE,
            value: DEFAULT_VALUE,
            gasLimit: DEFAULT_GAS_LIMIT,
            returnSizeLimit: DEFAULT_RETURN_SIZE_LIMIT,
            selector: DEFAULT_SELECTOR,
            data: DEFAULT_DATA,
            fee: DEFAULT_FEE
        });

        DEFAULT_MAX_EXECUTIONS = 1;
        DEFAULT_ACTION = address(callOnceAction);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice test typical CallOnceAction flow
    function test_callOnce_happyPath() public {
        buildInstruction();

        assertEq(address(user).balance, USER_START_BALANCE);

        vm.expectEmit();
        emit ICallOnceAction.CallOnceSucceeded(DEFAULT_TARGET, DEFAULT_SELECTOR, abi.encode("Hello, World!"));

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(address(user).balance, USER_START_BALANCE - DEFAULT_VALUE);
        assertEq(address(target).balance, DEFAULT_VALUE);
    }

    /// @notice test that execution fails with maxExecutions > 1
    function test_callOnce_maxExecutionsTooHigh() public {
        buildInstruction(DEFAULT_SALT, 2, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails with maxExecutions = 0
    function test_callOnce_maxExecutionsZero() public {
        buildInstruction(DEFAULT_SALT, 0, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails with target == address(0)
    function test_callOnce_targetZero() public {
        DEFAULT_ACTION_ARGS.target = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails with target == instructionStorage
    function test_callOnce_targetInstructionStorage() public {
        DEFAULT_ACTION_ARGS.target = address(instructionStorage);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution succeeds with allowFailure == true for a target that reverts
    function test_callOnce_happyPath_allowFailure() public {
        DEFAULT_ACTION_ARGS.target = address(new RevertTarget());
        DEFAULT_ACTION_ARGS.allowFailure = true;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit ICallOnceAction.CallOnceAttempted(DEFAULT_ACTION_ARGS.target, DEFAULT_SELECTOR, "");

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with user insufficient balance
    function test_callOnce_insufficientBalance() public {
        DEFAULT_ACTION_ARGS.value = USER_START_BALANCE + 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InsufficientBalance.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts when trying to call a non-existent function
    function test_callOnce_noSuchSelector() public {
        DEFAULT_ACTION_ARGS.selector = bytes4(0x12345678);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(
            CallOnceFailed.selector, DEFAULT_ACTION_ARGS.target, DEFAULT_ACTION_ARGS.selector, ""
        );
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts when the external call reverts and allowFailure == false
    function test_callOnce_targetRevert() public {
        DEFAULT_ACTION_ARGS.target = address(new RevertTarget());

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(
            CallOnceFailed.selector, DEFAULT_ACTION_ARGS.target, DEFAULT_ACTION_ARGS.selector, ""
        );
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts when a non-payable function is called with value and allowFailure == false
    function test_callOnce_targetNonPayable() public {
        DEFAULT_ACTION_ARGS.selector = target.helloWorldNonPayable.selector;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(
            CallOnceFailed.selector, DEFAULT_ACTION_ARGS.target, DEFAULT_ACTION_ARGS.selector, ""
        );
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts when the target consumes all gas and allowFailure == false
    function test_callOnce_targetOutOfGas() public {
        DEFAULT_ACTION_ARGS.target = address(new DrainGasTarget());

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(
            CallOnceFailed.selector, DEFAULT_ACTION_ARGS.target, DEFAULT_ACTION_ARGS.selector, ""
        );
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that return data is truncated when a return bomb is attempted
    function test_callOnce_returnBomb() public {
        uint256 returnBombSize = 70_000;
        ReturnBombTarget returnBombTarget = new ReturnBombTarget(returnBombSize);

        DEFAULT_ACTION_ARGS.target = address(returnBombTarget);
        DEFAULT_ACTION_ARGS.gasLimit = 100_000_000;
        DEFAULT_ACTION_ARGS.selector = ReturnBombTarget.returnBomb.selector;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        // construct the true error message returned by the target
        bytes memory errorMessage =
            abi.encodeWithSelector(ReturnBombTarget.ReturnBombError.selector, returnBombTarget.returnString());

        // truncate the error message to `DEFAULT_RETURN_SIZE_LIMIT` number of bytes
        bytes memory truncatedErrorMessage = new bytes(DEFAULT_RETURN_SIZE_LIMIT);
        for (uint256 i = 0; i < truncatedErrorMessage.length; i++) {
            truncatedErrorMessage[i] = errorMessage[i];
        }

        // check that the error message returned by the CallOnceAction is the truncated version
        bytes memory result = abi.encodeWithSelector(
            CallOnceFailed.selector, DEFAULT_ACTION_ARGS.target, DEFAULT_ACTION_ARGS.selector, truncatedErrorMessage
        );
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that return data is not copied when returnSizeLimit is 0
    function test_callOnce_noReturnData() public {
        uint256 returnBombSize = 70_000;
        ReturnBombTarget returnBombTarget = new ReturnBombTarget(returnBombSize);

        DEFAULT_ACTION_ARGS.target = address(returnBombTarget);
        DEFAULT_ACTION_ARGS.gasLimit = 100_000_000;
        DEFAULT_ACTION_ARGS.returnSizeLimit = 0;
        DEFAULT_ACTION_ARGS.selector = ReturnBombTarget.returnBomb.selector;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        // check that the error message returned by the CallOnceAction is the empty bytes
        bytes memory result = abi.encodeWithSelector(
            CallOnceFailed.selector, DEFAULT_ACTION_ARGS.target, DEFAULT_ACTION_ARGS.selector, ""
        );
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts when the user attempts reentrancy and allowFailure == false
    function test_callOnce_nonReentrant() public {
        buildInstruction();

        InstructionLib.Instruction memory alreadyActivatedInstruction = instruction;
        InstructionLib.Signature memory alreadyActivatedInstructionSig = instructionSig;

        user.executeInstruction(instruction, instructionSig);

        DEFAULT_ACTION_ARGS.target = address(user);
        DEFAULT_ACTION_ARGS.value = 0;
        DEFAULT_ACTION_ARGS.selector = IOtimDelegate.executeInstruction.selector;
        DEFAULT_ACTION_ARGS.data = abi.encode(alreadyActivatedInstruction, alreadyActivatedInstructionSig);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(
            CallOnceFailed.selector,
            DEFAULT_ACTION_ARGS.target,
            DEFAULT_ACTION_ARGS.selector,
            abi.encodeWithSelector(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector)
        );
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts when the user attempts reentrancy via Gateway and allowFailure == false
    function test_callOnce_nonReentrantGateway() public {
        buildInstruction();

        InstructionLib.Instruction memory alreadyActivatedInstruction = instruction;

        user.executeInstruction(instruction, instructionSig);

        DEFAULT_ACTION_ARGS.target = address(gateway);
        DEFAULT_ACTION_ARGS.value = 0;
        DEFAULT_ACTION_ARGS.gasLimit = 100_000;
        /// @dev this is the selector for the `safeExecuteInstruction(address,(uint256,uint256,address,bytes))` function
        DEFAULT_ACTION_ARGS.selector = bytes4(0x287399ff);
        DEFAULT_ACTION_ARGS.data = abi.encode(address(user), alreadyActivatedInstruction);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(
            CallOnceFailed.selector,
            DEFAULT_ACTION_ARGS.target,
            DEFAULT_ACTION_ARGS.selector,
            abi.encodeWithSelector(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector)
        );
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
