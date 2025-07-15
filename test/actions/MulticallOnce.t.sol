// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

// forge test suite
import {Test, console} from "forge-std/src/Test.sol";
import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {ReentrancyGuardTransient} from "@openzeppelin-contracts/utils/ReentrancyGuardTransient.sol";

import {ERC20MockWithDecimals} from "../mocks/ERC20MockWithDecimals.sol";
import {MockV3Aggregator} from "@chainlink-contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";
import {InstructionTestContext} from "../utils/InstructionTestContext.sol";

import {MockTarget} from "../mocks/MockTarget.sol";
import {RevertTarget} from "../mocks/RevertTarget.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

// Refuel action and IAction interface
import {IAction} from "../../src/actions/interfaces/IAction.sol";

import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {IMulticallOnceAction} from "../../src/actions/interfaces/IMulticallOnceAction.sol";
import {MulticallOnceAction} from "../../src/actions/MulticallOnceAction.sol";

import "../../src/actions/errors/Errors.sol";

contract MulticallOnceTest is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

    ERC20MockWithDecimals public USDC;

    MulticallOnceAction public multicall;

    MockTarget public target;

    /// @notice default Action arguments
    address public DEFAULT_TARGET;
    bool public DEFAULT_ALLOW_FAILURE;
    uint256 public DEFAULT_VALUE;
    uint256 public DEFAULT_GAS_LIMIT;
    uint16 public DEFAULT_RETURN_LIMIT;
    bytes4 public DEFAULT_SELECTOR;
    bytes public DEFAULT_DATA;
    IMulticallOnceAction.Subcall public DEFAULT_SUBCALL;

    IOtimFee.Fee public DEFAULT_FEE;

    constructor() {
        target = new MockTarget();

        USDC = new ERC20MockWithDecimals(6);

        multicall = new MulticallOnceAction(address(instructionStorage), address(0), address(0), 0);

        actionManager.addAction(address(multicall));

        DEFAULT_TARGET = address(target);
        DEFAULT_VALUE = 10;
        DEFAULT_GAS_LIMIT = 2300;
        DEFAULT_RETURN_LIMIT = 512;
        DEFAULT_SELECTOR = target.helloWorldPayable.selector;
        DEFAULT_DATA = abi.encode("");
        DEFAULT_SUBCALL = IMulticallOnceAction.Subcall({
            target: DEFAULT_TARGET,
            allowFailure: DEFAULT_ALLOW_FAILURE,
            value: DEFAULT_VALUE,
            gasLimit: DEFAULT_GAS_LIMIT,
            returnSizeLimit: DEFAULT_RETURN_LIMIT,
            selector: DEFAULT_SELECTOR,
            data: DEFAULT_DATA
        });
        IMulticallOnceAction.Subcall[] memory DEFAULT_SUBCALLS = new IMulticallOnceAction.Subcall[](1);
        DEFAULT_SUBCALLS[0] = DEFAULT_SUBCALL;

        IMulticallOnceAction.MulticallOnce memory DEFAULT_ACTION_ARGS =
            IMulticallOnceAction.MulticallOnce({subcalls: DEFAULT_SUBCALLS, fee: DEFAULT_FEE});

        /// @notice Instruction defaults
        DEFAULT_MAX_EXECUTIONS = 1;
        DEFAULT_ACTION = address(multicall);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical Multicall flow with one subcall
    function test_multicallOnce_happyPath() public {
        buildInstruction();

        assertEq(address(user).balance, USER_START_BALANCE);

        vm.expectEmit();
        emit IMulticallOnceAction.SubcallSucceeded(0, DEFAULT_TARGET, DEFAULT_SELECTOR, abi.encode("Hello, World!"));

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(address(user).balance, USER_START_BALANCE - DEFAULT_VALUE);
        assertEq(address(target).balance, DEFAULT_VALUE);
    }

    /// @notice typical Multicall flow with two subcalls
    function test_multicallOnce_happyPath_multi() public {
        IMulticallOnceAction.Subcall memory extraSubcall = IMulticallOnceAction.Subcall({
            target: DEFAULT_TARGET,
            allowFailure: DEFAULT_ALLOW_FAILURE,
            value: DEFAULT_VALUE,
            gasLimit: DEFAULT_GAS_LIMIT,
            returnSizeLimit: DEFAULT_RETURN_LIMIT,
            selector: target.helloWorldPayable.selector,
            data: abi.encode("")
        });

        IMulticallOnceAction.Subcall[] memory DEFAULT_SUBCALLS = new IMulticallOnceAction.Subcall[](2);
        DEFAULT_SUBCALLS[0] = DEFAULT_SUBCALL;
        DEFAULT_SUBCALLS[1] = extraSubcall;

        IMulticallOnceAction.MulticallOnce memory arguments =
            IMulticallOnceAction.MulticallOnce({subcalls: DEFAULT_SUBCALLS, fee: DEFAULT_FEE});

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(arguments));

        assertEq(address(user).balance, USER_START_BALANCE);

        vm.expectEmit();
        emit IMulticallOnceAction.SubcallSucceeded(0, DEFAULT_TARGET, DEFAULT_SELECTOR, abi.encode("Hello, World!"));

        vm.expectEmit();
        emit IMulticallOnceAction.SubcallSucceeded(1, DEFAULT_TARGET, DEFAULT_SELECTOR, abi.encode("Hello, World!"));

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(address(user).balance, USER_START_BALANCE - 2 * DEFAULT_VALUE);
        assertEq(address(target).balance, 2 * DEFAULT_VALUE);
    }

    /// @notice test that when a subcall fails, the instruction is deactivated and an event is emitted
    function test_multicallOnce_happyPath_allowFailure() public {
        address badTarget = address(new RevertTarget());

        DEFAULT_SUBCALL.target = badTarget;
        DEFAULT_SUBCALL.allowFailure = true;

        IMulticallOnceAction.Subcall[] memory DEFAULT_SUBCALLS = new IMulticallOnceAction.Subcall[](1);
        DEFAULT_SUBCALLS[0] = DEFAULT_SUBCALL;

        IMulticallOnceAction.MulticallOnce memory badArguments =
            IMulticallOnceAction.MulticallOnce({subcalls: DEFAULT_SUBCALLS, fee: DEFAULT_FEE});

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(badArguments));

        vm.expectEmit();
        emit IMulticallOnceAction.SubcallAttempted(0, badTarget, DEFAULT_SELECTOR, "");

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails with maxExecutions > 1
    function test_multicallOnce_maxExecutionsTooHigh() public {
        IMulticallOnceAction.Subcall[] memory DEFAULT_SUBCALLS = new IMulticallOnceAction.Subcall[](1);
        DEFAULT_SUBCALLS[0] = DEFAULT_SUBCALL;

        IMulticallOnceAction.MulticallOnce memory arguments =
            IMulticallOnceAction.MulticallOnce({subcalls: DEFAULT_SUBCALLS, fee: DEFAULT_FEE});

        buildInstruction(DEFAULT_SALT, 2, DEFAULT_ACTION, abi.encode(arguments));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails with maxExecutions = 0
    function test_multicallOnce_maxExecutionsZero() public {
        IMulticallOnceAction.Subcall[] memory DEFAULT_SUBCALLS = new IMulticallOnceAction.Subcall[](1);
        DEFAULT_SUBCALLS[0] = DEFAULT_SUBCALL;

        IMulticallOnceAction.MulticallOnce memory arguments =
            IMulticallOnceAction.MulticallOnce({subcalls: DEFAULT_SUBCALLS, fee: DEFAULT_FEE});

        buildInstruction(DEFAULT_SALT, 0, DEFAULT_ACTION, abi.encode(arguments));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the multicall breaks after a failed subcall
    function test_multicallOnce_breakAfterFailedSubcall() public {
        IMulticallOnceAction.Subcall memory subcall1 = IMulticallOnceAction.Subcall({
            target: DEFAULT_TARGET,
            allowFailure: DEFAULT_ALLOW_FAILURE,
            value: DEFAULT_VALUE,
            gasLimit: DEFAULT_GAS_LIMIT,
            returnSizeLimit: DEFAULT_RETURN_LIMIT,
            selector: target.helloWorldNonPayable.selector,
            data: abi.encode("")
        });

        IMulticallOnceAction.Subcall memory subcall2 = IMulticallOnceAction.Subcall({
            target: DEFAULT_TARGET,
            allowFailure: DEFAULT_ALLOW_FAILURE,
            value: DEFAULT_VALUE,
            gasLimit: DEFAULT_GAS_LIMIT,
            returnSizeLimit: DEFAULT_RETURN_LIMIT,
            selector: target.helloWorldPayable.selector,
            data: abi.encode("")
        });

        IMulticallOnceAction.Subcall[] memory DEFAULT_SUBCALLS = new IMulticallOnceAction.Subcall[](3);
        DEFAULT_SUBCALLS[0] = DEFAULT_SUBCALL;
        DEFAULT_SUBCALLS[1] = subcall1;
        DEFAULT_SUBCALLS[2] = subcall2;

        IMulticallOnceAction.MulticallOnce memory arguments =
            IMulticallOnceAction.MulticallOnce({subcalls: DEFAULT_SUBCALLS, fee: DEFAULT_FEE});

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(arguments));

        bytes memory result =
            abi.encodeWithSelector(SubcallFailed.selector, 1, DEFAULT_TARGET, target.helloWorldNonPayable.selector, "");
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with target == address(0)
    function test_multicallOnce_targetZero() public {
        DEFAULT_SUBCALL.target = address(0);

        IMulticallOnceAction.Subcall[] memory DEFAULT_SUBCALLS = new IMulticallOnceAction.Subcall[](1);
        DEFAULT_SUBCALLS[0] = DEFAULT_SUBCALL;

        IMulticallOnceAction.MulticallOnce memory badArguments =
            IMulticallOnceAction.MulticallOnce({subcalls: DEFAULT_SUBCALLS, fee: DEFAULT_FEE});

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(badArguments));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);

        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with target == instructionStorage
    function test_multicallOnce_targetInstructionStorage() public {
        DEFAULT_SUBCALL.target = address(instructionStorage);

        IMulticallOnceAction.Subcall[] memory DEFAULT_SUBCALLS = new IMulticallOnceAction.Subcall[](1);
        DEFAULT_SUBCALLS[0] = DEFAULT_SUBCALL;

        IMulticallOnceAction.MulticallOnce memory badArguments =
            IMulticallOnceAction.MulticallOnce({subcalls: DEFAULT_SUBCALLS, fee: DEFAULT_FEE});

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(badArguments));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);

        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with user insufficient balance
    function test_multicallOnce_insufficientBalance() public {
        DEFAULT_SUBCALL.value = 1;

        IMulticallOnceAction.Subcall[] memory DEFAULT_SUBCALLS = new IMulticallOnceAction.Subcall[](1);
        DEFAULT_SUBCALLS[0] = DEFAULT_SUBCALL;

        IMulticallOnceAction.MulticallOnce memory badArguments =
            IMulticallOnceAction.MulticallOnce({subcalls: DEFAULT_SUBCALLS, fee: DEFAULT_FEE});

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(badArguments));

        vm.deal(address(user), 0);

        bytes memory result = abi.encodeWithSelector(InsufficientBalance.selector);

        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with user insufficient balance
    function test_multicallOnce_insufficientBalance_multi() public {
        IMulticallOnceAction.Subcall memory insufficientBalanceSubcall = IMulticallOnceAction.Subcall({
            target: DEFAULT_TARGET,
            allowFailure: DEFAULT_ALLOW_FAILURE,
            value: 1,
            gasLimit: DEFAULT_GAS_LIMIT,
            returnSizeLimit: DEFAULT_RETURN_LIMIT,
            selector: target.helloWorldPayable.selector,
            data: abi.encode("")
        });

        IMulticallOnceAction.Subcall[] memory DEFAULT_SUBCALLS = new IMulticallOnceAction.Subcall[](2);
        DEFAULT_SUBCALLS[0] = DEFAULT_SUBCALL;
        DEFAULT_SUBCALLS[1] = insufficientBalanceSubcall;

        IMulticallOnceAction.MulticallOnce memory badArguments =
            IMulticallOnceAction.MulticallOnce({subcalls: DEFAULT_SUBCALLS, fee: DEFAULT_FEE});

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(badArguments));

        vm.deal(address(user), 0);

        bytes memory result = abi.encodeWithSelector(InsufficientBalance.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that when a subcall fails, the instruction is deactivated and an event is emitted
    function test_multicallOnce_targetRevert() public {
        address badTarget = address(new RevertTarget());

        DEFAULT_SUBCALL.target = badTarget;

        IMulticallOnceAction.Subcall[] memory DEFAULT_SUBCALLS = new IMulticallOnceAction.Subcall[](1);
        DEFAULT_SUBCALLS[0] = DEFAULT_SUBCALL;

        IMulticallOnceAction.MulticallOnce memory badArguments =
            IMulticallOnceAction.MulticallOnce({subcalls: DEFAULT_SUBCALLS, fee: DEFAULT_FEE});

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(badArguments));

        bytes memory result = abi.encodeWithSelector(SubcallFailed.selector, 0, badTarget, DEFAULT_SELECTOR, "");
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that when a subcall fails due to the selctor not existing on the target, the instruction is deactivated and an event is emitted
    function test_multicallOnce_noSuchSelector() public {
        DEFAULT_SUBCALL.selector = bytes4(0x12345678);

        IMulticallOnceAction.Subcall[] memory DEFAULT_SUBCALLS = new IMulticallOnceAction.Subcall[](1);
        DEFAULT_SUBCALLS[0] = DEFAULT_SUBCALL;

        IMulticallOnceAction.MulticallOnce memory badArguments =
            IMulticallOnceAction.MulticallOnce({subcalls: DEFAULT_SUBCALLS, fee: DEFAULT_FEE});

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(badArguments));

        bytes memory result =
            abi.encodeWithSelector(SubcallFailed.selector, 0, DEFAULT_TARGET, DEFAULT_SUBCALL.selector, "");
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that when a subcall fails due to the target not being payable, the instruction is deactivated and an event is emitted
    function test_multicallOnce_targetNonPayable() public {
        DEFAULT_SUBCALL.selector = target.helloWorldNonPayable.selector;

        IMulticallOnceAction.Subcall[] memory DEFAULT_SUBCALLS = new IMulticallOnceAction.Subcall[](1);
        DEFAULT_SUBCALLS[0] = DEFAULT_SUBCALL;

        IMulticallOnceAction.MulticallOnce memory badArguments =
            IMulticallOnceAction.MulticallOnce({subcalls: DEFAULT_SUBCALLS, fee: DEFAULT_FEE});

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(badArguments));

        bytes memory result =
            abi.encodeWithSelector(SubcallFailed.selector, 0, DEFAULT_TARGET, DEFAULT_SUBCALL.selector, "");
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that when a subcall fails due to a reentrancy attmpt, the instruction is deactivated and an event is emitted
    function test_multicallOnce_nonReentrant() public {
        buildInstruction();

        InstructionLib.Instruction memory alreadyActivatedInstruction = instruction;
        InstructionLib.Signature memory alreadyActivatedInstructionSig = instructionSig;

        user.executeInstruction(instruction, instructionSig);

        DEFAULT_SUBCALL = IMulticallOnceAction.Subcall({
            target: address(user),
            allowFailure: DEFAULT_ALLOW_FAILURE,
            value: 0,
            gasLimit: DEFAULT_GAS_LIMIT,
            returnSizeLimit: DEFAULT_RETURN_LIMIT,
            selector: IOtimDelegate.executeInstruction.selector,
            data: abi.encode(alreadyActivatedInstruction, alreadyActivatedInstructionSig)
        });

        IMulticallOnceAction.Subcall[] memory DEFAULT_SUBCALLS = new IMulticallOnceAction.Subcall[](1);
        DEFAULT_SUBCALLS[0] = DEFAULT_SUBCALL;

        IMulticallOnceAction.MulticallOnce memory arguments =
            IMulticallOnceAction.MulticallOnce({subcalls: DEFAULT_SUBCALLS, fee: DEFAULT_FEE});

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(arguments));

        bytes memory subResult = abi.encodeWithSelector(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
        bytes memory result = abi.encodeWithSelector(
            SubcallFailed.selector, 0, address(user), IOtimDelegate.executeInstruction.selector, subResult
        );
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that when a subcall fails due to a reentrancy attmpt, the instruction is deactivated and an event is emitted
    function test_multicallOnce_nonReentrantGateway() public {
        buildInstruction();

        InstructionLib.Instruction memory alreadyActivatedInstruction = instruction;

        user.executeInstruction(instruction, instructionSig);

        DEFAULT_SUBCALL = IMulticallOnceAction.Subcall({
            target: address(gateway),
            allowFailure: false,
            value: 0,
            gasLimit: 100_000,
            returnSizeLimit: DEFAULT_RETURN_LIMIT,
            selector: bytes4(0x287399ff),
            data: abi.encode(address(user), alreadyActivatedInstruction)
        });

        IMulticallOnceAction.Subcall[] memory DEFAULT_SUBCALLS = new IMulticallOnceAction.Subcall[](1);
        DEFAULT_SUBCALLS[0] = DEFAULT_SUBCALL;

        IMulticallOnceAction.MulticallOnce memory arguments =
            IMulticallOnceAction.MulticallOnce({subcalls: DEFAULT_SUBCALLS, fee: DEFAULT_FEE});

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(arguments));

        bytes memory subResult = abi.encodeWithSelector(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
        bytes memory result =
            abi.encodeWithSelector(SubcallFailed.selector, 0, address(gateway), bytes4(0x287399ff), subResult);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
