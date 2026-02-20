// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {InstructionTestContext} from "../utils/InstructionTestContext.sol";

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ERC20MockWithDecimals} from "../mocks/ERC20MockWithDecimals.sol";
import {ERC7540DepositMock} from "../mocks/ERC7540DepositMock.sol";
import {ERC4626Mock} from "../mocks/ERC4626Mock.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {ISweepRequestDepositERC7540Action} from "../../src/actions/interfaces/ISweepRequestDepositERC7540Action.sol";
import {SweepRequestDepositERC7540Action} from "../../src/actions/SweepRequestDepositERC7540Action.sol";
import {IERC7540Deposit} from "../../src/actions/external/IERC7540.sol";

import "../../src/actions/errors/Errors.sol";

contract SweepRequestDepositERC7540Test is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

    SweepRequestDepositERC7540Action public sweepRequestDepositERC7540 =
        new SweepRequestDepositERC7540Action(address(0), address(0), 0);

    ERC20MockWithDecimals public mockUSDC = new ERC20MockWithDecimals(6);

    ERC4626Mock public underlyingVault = new ERC4626Mock(IERC20(mockUSDC));

    ERC7540DepositMock public mockVault = new ERC7540DepositMock(IERC20(underlyingVault));

    address public DEFAULT_VAULT = address(mockVault);
    address public DEFAULT_CONTROLLER = address(user);
    uint256 public DEFAULT_THRESHOLD;
    uint256 public DEFAULT_END_BALANCE;
    uint256 public DEFAULT_MIN_DEPOSIT;
    uint256 public DEFAULT_MIN_TOTAL_SHARES = 100e6;

    IOtimFee.Fee public DEFAULT_FEE;

    ISweepRequestDepositERC7540Action.SweepRequestDepositERC7540 public DEFAULT_ACTION_ARGS;

    constructor() {
        USER_START_BALANCE = 100_000e6;

        mockUSDC.mint(address(user), USER_START_BALANCE);
        vm.startPrank(address(user));
        mockUSDC.approve(address(underlyingVault), USER_START_BALANCE);
        uint256 vaultShares = underlyingVault.deposit(USER_START_BALANCE, address(user));
        vm.stopPrank();

        DEFAULT_THRESHOLD = vaultShares;
        DEFAULT_MIN_DEPOSIT = vaultShares - DEFAULT_END_BALANCE;

        actionManager.addAction(address(sweepRequestDepositERC7540));

        DEFAULT_ACTION_ARGS = ISweepRequestDepositERC7540Action.SweepRequestDepositERC7540({
            vault: DEFAULT_VAULT,
            controller: DEFAULT_CONTROLLER,
            threshold: DEFAULT_THRESHOLD,
            endBalance: DEFAULT_END_BALANCE,
            minDeposit: DEFAULT_MIN_DEPOSIT,
            minTotalShares: DEFAULT_MIN_TOTAL_SHARES,
            fee: DEFAULT_FEE
        });

        DEFAULT_ACTION = address(sweepRequestDepositERC7540);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical sweep flow: balance >= threshold, requestDeposit(balance - endBalance)
    function test_sweepRequestDepositERC7540_happyPath() public {
        buildInstruction();

        vm.expectEmit(true, true, true, false);
        emit IERC7540Deposit.DepositRequest(DEFAULT_CONTROLLER, address(user), 0, address(user), DEFAULT_MIN_DEPOSIT);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(IERC20(underlyingVault).balanceOf(address(user)), DEFAULT_END_BALANCE);
        assertEq(mockVault.pendingDepositRequest(0, DEFAULT_CONTROLLER), DEFAULT_MIN_DEPOSIT);
    }

    /// @notice test that validation fails with vault == address(0)
    function test_sweepRequestDepositERC7540_vaultZero() public {
        DEFAULT_ACTION_ARGS.vault = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with controller == address(0)
    function test_sweepRequestDepositERC7540_controllerZero() public {
        DEFAULT_ACTION_ARGS.controller = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with endBalance > threshold
    function test_sweepRequestDepositERC7540_endBalanceOverThreshold() public {
        DEFAULT_ACTION_ARGS.endBalance = DEFAULT_THRESHOLD + 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with minTotalShares == 0
    function test_sweepRequestDepositERC7540_minTotalSharesZero() public {
        DEFAULT_ACTION_ARGS.minTotalShares = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with balance under threshold
    function test_sweepRequestDepositERC7540_balanceUnderThreshold() public {
        DEFAULT_THRESHOLD = DEFAULT_THRESHOLD + 1;
        DEFAULT_ACTION_ARGS.threshold = DEFAULT_THRESHOLD;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        assertEq(IERC20(underlyingVault).balanceOf(address(user)), DEFAULT_THRESHOLD - 1);

        bytes memory result = abi.encodeWithSelector(BalanceUnderThreshold.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts when request amount is less than minDeposit (sweep amount too small)
    function test_sweepRequestDepositERC7540_maxDepositTooLow() public {
        DEFAULT_ACTION_ARGS.minDeposit = DEFAULT_MIN_DEPOSIT + 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(MaxDepositTooLow.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with total shares too low
    function test_sweepRequestDepositERC7540_totalSharesTooLow() public {
        mockVault.setTotalSupply(DEFAULT_MIN_TOTAL_SHARES - 1);

        buildInstruction();

        bytes memory result = abi.encodeWithSelector(TotalSharesTooLow.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
