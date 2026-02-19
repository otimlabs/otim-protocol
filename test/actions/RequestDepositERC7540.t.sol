// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {InstructionTestContext} from "../utils/InstructionTestContext.sol";

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ERC20MockWithDecimals} from "../mocks/ERC20MockWithDecimals.sol";
import {ERC4626Mock} from "../mocks/ERC4626Mock.sol";
import {ERC7540DepositMock} from "../mocks/ERC7540DepositMock.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {IInterval} from "../../src/actions/schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {IRequestDepositERC7540Action} from "../../src/actions/interfaces/IRequestDepositERC7540Action.sol";
import {RequestDepositERC7540Action} from "../../src/actions/RequestDepositERC7540Action.sol";
import {IERC7540Deposit} from "../../src/actions/external/IERC7540.sol";

import "../../src/actions/errors/Errors.sol";

contract RequestDepositERC7540Test is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

    RequestDepositERC7540Action public requestDepositERC7540 =
        new RequestDepositERC7540Action(address(0), address(0), 0);

    ERC20MockWithDecimals public mockUSDC = new ERC20MockWithDecimals(6);

    ERC4626Mock public underlyingVault = new ERC4626Mock(IERC20(mockUSDC));

    ERC7540DepositMock public mockVault = new ERC7540DepositMock(IERC20(underlyingVault));

    address public DEFAULT_VAULT = address(mockVault);
    address public DEFAULT_RECIPIENT = address(user);
    address public DEFAULT_CONTROLLER = address(user);
    uint256 public DEFAULT_ASSETS;
    uint256 public DEFAULT_MIN_DEPOSIT;
    uint256 public DEFAULT_MIN_TOTAL_SHARES = 100e6;

    IInterval.Schedule public DEFAULT_SCHEDULE;
    IOtimFee.Fee public DEFAULT_FEE;

    IRequestDepositERC7540Action.RequestDepositERC7540 public DEFAULT_ACTION_ARGS;

    constructor() {
        USER_START_BALANCE = 100_000e6;

        mockUSDC.mint(address(user), USER_START_BALANCE);
        vm.startPrank(address(user));
        mockUSDC.approve(address(underlyingVault), USER_START_BALANCE);
        uint256 vaultShares = underlyingVault.deposit(USER_START_BALANCE, address(user));
        vm.stopPrank();

        DEFAULT_ASSETS = vaultShares;
        DEFAULT_MIN_DEPOSIT = vaultShares;

        actionManager.addAction(address(requestDepositERC7540));

        DEFAULT_ACTION_ARGS = IRequestDepositERC7540Action.RequestDepositERC7540({
            vault: DEFAULT_VAULT,
            assets: DEFAULT_ASSETS,
            recipient: DEFAULT_RECIPIENT,
            controller: DEFAULT_CONTROLLER,
            minDeposit: DEFAULT_MIN_DEPOSIT,
            minTotalShares: DEFAULT_MIN_TOTAL_SHARES,
            schedule: DEFAULT_SCHEDULE,
            fee: DEFAULT_FEE
        });

        DEFAULT_ACTION = address(requestDepositERC7540);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical requestDeposit flow: user has balance, instruction executes requestDeposit
    function test_requestDepositERC7540_happyPath() public {
        buildInstruction();

        vm.expectEmit(true, true, true, false);
        emit IERC7540Deposit.DepositRequest(DEFAULT_CONTROLLER, address(user), 0, address(user), DEFAULT_ASSETS);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        uint256 startBalance = IERC20(underlyingVault).balanceOf(address(user));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(IERC20(underlyingVault).balanceOf(address(user)), startBalance - DEFAULT_ASSETS);
        assertEq(mockVault.pendingDepositRequest(0, DEFAULT_CONTROLLER), DEFAULT_ASSETS);
    }

    /// @notice test that validation fails with vault == address(0)
    function test_requestDepositERC7540_vaultZero() public {
        DEFAULT_ACTION_ARGS.vault = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with recipient == address(0)
    function test_requestDepositERC7540_recipientZero() public {
        DEFAULT_ACTION_ARGS.recipient = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with controller == address(0)
    function test_requestDepositERC7540_controllerZero() public {
        DEFAULT_ACTION_ARGS.controller = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with assets == 0
    function test_requestDepositERC7540_assetsZero() public {
        DEFAULT_ACTION_ARGS.assets = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with minTotalShares == 0
    function test_requestDepositERC7540_minTotalSharesZero() public {
        DEFAULT_ACTION_ARGS.minTotalShares = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with total shares too low
    function test_requestDepositERC7540_totalSharesTooLow() public {
        mockVault.setTotalSupply(DEFAULT_MIN_TOTAL_SHARES - 1);

        buildInstruction();

        bytes memory result = abi.encodeWithSelector(TotalSharesTooLow.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts when pending deposit is less than minDeposit (mock returns same as requested; use minDeposit > assets)
    function test_requestDepositERC7540_maxDepositTooLow() public {
        DEFAULT_ACTION_ARGS.minDeposit = DEFAULT_MIN_DEPOSIT + 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(MaxDepositTooLow.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with user insufficient balance
    function test_requestDepositERC7540_insufficientBalance() public {
        DEFAULT_ACTION_ARGS.assets = DEFAULT_ASSETS + 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InsufficientBalance.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
