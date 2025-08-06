// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {VmSafe} from "forge-std/src/Vm.sol";

import {InstructionTestContext} from "../utils/InstructionTestContext.sol";

import {ERC20MockWithDecimals} from "../mocks/ERC20MockWithDecimals.sol";
import {BadERC20Mock} from "../mocks/BadERC20.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {ISweepERC20Action} from "../../src/actions/interfaces/ISweepERC20Action.sol";
import {SweepERC20Action} from "../../src/actions/SweepERC20Action.sol";

import "../../src/actions/errors/Errors.sol";

contract SweepERC20Test is InstructionTestContext {
    using SafeERC20 for IERC20;
    using InstructionLib for InstructionLib.Instruction;

    ERC20MockWithDecimals public USDC = new ERC20MockWithDecimals(6);

    SweepERC20Action public sweepERC20 = new SweepERC20Action(address(0), address(0), 0);

    /// @notice test Sweep target
    VmSafe.Wallet public target = vm.createWallet("target");

    /// @notice default Action arguments
    address public DEFAULT_TOKEN = address(USDC);
    address public DEFAULT_TARGET = target.addr;
    uint256 public DEFAULT_THRESHOLD = 500;
    uint256 public DEFAULT_END_BALANCE = 200;

    IOtimFee.Fee public DEFAULT_FEE;

    ISweepERC20Action.SweepERC20 public DEFAULT_ACTION_ARGS = ISweepERC20Action.SweepERC20({
        token: DEFAULT_TOKEN,
        target: DEFAULT_TARGET,
        threshold: DEFAULT_THRESHOLD,
        endBalance: DEFAULT_END_BALANCE,
        fee: DEFAULT_FEE
    });

    constructor() {
        /// @notice Action setup
        actionManager.addAction(address(sweepERC20));

        /// @notice Instruction defaults
        DEFAULT_ACTION = address(sweepERC20);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical SweepERC20 flow
    function test_sweepERC20_happyPath() public {
        buildInstruction();

        USDC.mint(address(user), USER_START_BALANCE);

        assertEq(USDC.balanceOf(address(user)), USER_START_BALANCE);
        assertEq(USDC.balanceOf(target.addr), 0);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(USDC.balanceOf(address(user)), DEFAULT_END_BALANCE);
        assertEq(USDC.balanceOf(target.addr), USER_START_BALANCE - DEFAULT_END_BALANCE);
    }

    /// @notice test that execution succeeds with threshold == endBalance
    function test_sweepERC20_happyPath_thresholdEqualsEndBalance() public {
        // keep defaults but set threshold to endBalance
        DEFAULT_ACTION_ARGS.threshold = DEFAULT_END_BALANCE;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        USDC.mint(address(user), USER_START_BALANCE);

        assertEq(USDC.balanceOf(address(user)), USER_START_BALANCE);
        assertEq(USDC.balanceOf(target.addr), 0);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(USDC.balanceOf(address(user)), DEFAULT_END_BALANCE);
        assertEq(USDC.balanceOf(target.addr), USER_START_BALANCE - DEFAULT_END_BALANCE);
    }

    /// @notice test that execution succeeds when balance is exactly equal to the threshold (and endBalance is less than threshold)
    function test_sweepERC20_happyPath_balanceEqualsThreshold() public {
        DEFAULT_ACTION_ARGS.threshold = USER_START_BALANCE;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        USDC.mint(address(user), USER_START_BALANCE);

        assertEq(USDC.balanceOf(address(user)), USER_START_BALANCE);
        assertEq(USDC.balanceOf(target.addr), 0);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(USDC.balanceOf(address(user)), DEFAULT_END_BALANCE);
        assertEq(USDC.balanceOf(target.addr), USER_START_BALANCE - DEFAULT_END_BALANCE);
    }

    /// @notice test validation reverts with token == address(0)
    function test_sweepERC20_tokenZero() public {
        // keep defaults but set token to address(0)
        DEFAULT_ACTION_ARGS.token = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test validation reverts with target == address(0)
    function test_sweepERC20_targetZero() public {
        // keep defaults but set target to address(0)
        DEFAULT_ACTION_ARGS.target = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution fails with endBalance above threshold
    function test_sweepERC20_endBalanceAboveThreshold() public {
        // keep defaults but set endBalance above threshold
        DEFAULT_ACTION_ARGS.endBalance = DEFAULT_THRESHOLD + 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with ERC20 balance under threshold
    function test_sweepERC20_balanceUnderThreshold() public {
        // Note: we don't mint any tokens to the user here so the balance is zero

        assertEq(USDC.balanceOf(address(user)), 0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(BalanceUnderThreshold.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with ERC20 balance == endBalance
    /// @dev this is so the Instruction doesn't execute unnecessarily when the threshsold == endBalance
    function test_sweepERC20_balanceEqualsEndBalance() public {
        DEFAULT_ACTION_ARGS.threshold = USER_START_BALANCE;
        DEFAULT_ACTION_ARGS.endBalance = USER_START_BALANCE;

        USDC.mint(address(user), USER_START_BALANCE);

        assertEq(USDC.balanceOf(address(user)), USER_START_BALANCE);
        assertEq(USDC.balanceOf(target.addr), 0);

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
    function test_sweepERC20_balanceZero() public {
        // Note: we don't mint any tokens to the user here so the balance is zero

        DEFAULT_ACTION_ARGS.threshold = 0;
        DEFAULT_ACTION_ARGS.endBalance = 0;

        assertEq(USDC.balanceOf(address(user)), 0);
        assertEq(USDC.balanceOf(target.addr), 0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(BalanceUnderThreshold.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with token transfer failure
    function test_sweepERC20_tokenTransferRevert() public {
        BadERC20Mock badMockToken = new BadERC20Mock();

        // keep defaults but set token to badMockToken
        DEFAULT_ACTION_ARGS.token = address(badMockToken);

        badMockToken.mint(address(user), USER_START_BALANCE);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(badMockToken));
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
