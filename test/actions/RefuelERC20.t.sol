// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {InstructionTestContext} from "../utils/InstructionTestContext.sol";

import {ERC20MockWithDecimals} from "../mocks/ERC20MockWithDecimals.sol";
import {BadERC20Mock} from "../mocks/BadERC20.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {IRefuelERC20Action} from "../../src/actions/interfaces/IRefuelERC20Action.sol";
import {RefuelERC20Action} from "../../src/actions/RefuelERC20Action.sol";

import "../../src/actions/errors/Errors.sol";

contract RefuelERC20Test is InstructionTestContext {
    using SafeERC20 for IERC20;
    using InstructionLib for InstructionLib.Instruction;

    ERC20MockWithDecimals public USDC = new ERC20MockWithDecimals(6);

    RefuelERC20Action public refuelERC20 = new RefuelERC20Action(address(0), address(0), 0);

    /// @notice test Refuel target
    VmSafe.Wallet public target = vm.createWallet("target");

    /// @notice user and target starting balances
    uint256 public TARGET_START_BALANCE = 50;

    /// @notice default Action arguments
    address public DEFAULT_TOKEN = address(USDC);
    address public DEFAULT_TARGET = target.addr;
    uint256 public DEFAULT_THRESHOLD = 100;
    uint256 public DEFAULT_END_BALANCE = 500;

    IOtimFee.Fee public DEFAULT_FEE;

    IRefuelERC20Action.RefuelERC20 public DEFAULT_ACTION_ARGS = IRefuelERC20Action.RefuelERC20({
        token: DEFAULT_TOKEN,
        target: DEFAULT_TARGET,
        threshold: DEFAULT_THRESHOLD,
        endBalance: DEFAULT_END_BALANCE,
        fee: DEFAULT_FEE
    });

    constructor() {
        /// @notice Action setup
        actionManager.addAction(address(refuelERC20));

        /// @notice Instruction defaults
        DEFAULT_ACTION = address(refuelERC20);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical RefuelERC20 flow
    function test_refuelERC20_happyPath() public {
        vm.pauseGasMetering();

        buildInstruction();

        USDC.mint(address(user), USER_START_BALANCE);
        USDC.mint(target.addr, TARGET_START_BALANCE);

        assertEq(USDC.balanceOf(address(user)), USER_START_BALANCE);
        assertEq(USDC.balanceOf(target.addr), TARGET_START_BALANCE);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(USDC.balanceOf(address(user)), USER_START_BALANCE - (DEFAULT_END_BALANCE - TARGET_START_BALANCE));
        assertEq(USDC.balanceOf(target.addr), DEFAULT_END_BALANCE);
    }

    /// @notice typical RefuelERC20 flow with threshold == 0
    function test_refuelERC20_happyPath_thresholdZero() public {
        vm.pauseGasMetering();

        // keep defaults but set threshold to 0
        DEFAULT_ACTION_ARGS.threshold = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        USDC.mint(address(user), USER_START_BALANCE);

        assertEq(USDC.balanceOf(address(user)), USER_START_BALANCE);
        assertEq(USDC.balanceOf(target.addr), 0);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(USDC.balanceOf(address(user)), USER_START_BALANCE - DEFAULT_END_BALANCE);
        assertEq(USDC.balanceOf(target.addr), DEFAULT_END_BALANCE);
    }

    /// @notice test validation reverts with token == address(0)
    function test_refuelERC20_tokenZero() public {
        vm.pauseGasMetering();

        // keep defaults but set token to address(0)
        DEFAULT_ACTION_ARGS.token = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test validation reverts with target == address(0)
    function test_refuelERC20_targetZero() public {
        vm.pauseGasMetering();

        // keep defaults but set target to address(0)
        DEFAULT_ACTION_ARGS.target = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with threshold above endBalance
    function test_refuelERC20_thresholdAboveEndBalance() public {
        vm.pauseGasMetering();

        // keep defaults but set threshold to above endBalance
        DEFAULT_ACTION_ARGS.threshold = DEFAULT_END_BALANCE + 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with threshold == endBalance
    function test_refuelERC20_thresholdEqualsEndBalance() public {
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

    /// @notice test that execution reverts with target ERC20 token balance over threshold
    function test_refuelERC20_balanceOverThreshold() public {
        vm.pauseGasMetering();

        buildInstruction();

        USDC.mint(address(user), USER_START_BALANCE);
        USDC.mint(target.addr, DEFAULT_THRESHOLD + 1);

        bytes memory result = abi.encodeWithSelector(BalanceOverThreshold.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with ERC20 token insufficient balance
    function test_refuelERC20_insufficientBalance() public {
        vm.pauseGasMetering();

        buildInstruction();

        USDC.mint(target.addr, TARGET_START_BALANCE);

        bytes memory result = abi.encodeWithSelector(InsufficientBalance.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that fee routing reverts with invalid fee token
    function test_refuelERC20_tokenTransferRevert() public {
        vm.pauseGasMetering();

        BadERC20Mock badMockToken = new BadERC20Mock();

        // keep defaults but set token to badMockToken
        DEFAULT_ACTION_ARGS.token = address(badMockToken);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        badMockToken.mint(address(user), USER_START_BALANCE);

        bytes memory result = abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(badMockToken));
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
