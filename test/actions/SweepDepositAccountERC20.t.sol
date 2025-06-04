// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/src/Test.sol";
import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {ERC20Mock} from "@openzeppelin-contracts/mocks/token/ERC20Mock.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";
import {InstructionForkTestContext} from "../utils/InstructionForkTestContext.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {FeeTokenRegistry} from "../../src/infrastructure/FeeTokenRegistry.sol";
import {Treasury} from "../../src/infrastructure/Treasury.sol";

import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {ISweepDepositAccountERC20Action} from "../../src/actions/interfaces/ISweepDepositAccountERC20Action.sol";
import {SweepDepositAccountERC20Action} from "../../src/actions/SweepDepositAccountERC20Action.sol";

import {DepositAccount} from "../../src/actions/transient-contracts/DepositAccount.sol";

import "../../src/actions/errors/Errors.sol";

contract SweepDepositAccountERC20Test is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    VmSafe.Wallet public depositor;
    VmSafe.Wallet public recipient;

    SweepDepositAccountERC20Action public sweepDepositAccountERC20Action;
    ERC20Mock public mockERC20;

    address public DEFAULT_DEPOSIT_ACCOUNT;

    address public DEFAULT_TOKEN;
    address public DEFAULT_DEPOSITOR;
    address public DEFAULT_RECIPIENT;
    uint256 public DEFAULT_THRESHOLD;

    IOtimFee.Fee public DEFAULT_FEE;

    ISweepDepositAccountERC20Action.SweepDepositAccountERC20 public DEFAULT_ACTION_ARGS;

    constructor() {
        depositor = vm.createWallet("depositor");
        recipient = vm.createWallet("recipient");

        /// @notice Action setup
        sweepDepositAccountERC20Action = new SweepDepositAccountERC20Action(address(0), address(0), 0);

        actionManager.addAction(address(sweepDepositAccountERC20Action));

        DEFAULT_DEPOSIT_ACCOUNT = sweepDepositAccountERC20Action.calculateDepositAddress(address(user), depositor.addr);

        mockERC20 = new ERC20Mock();

        mockERC20.mint(address(user), USER_START_BALANCE);

        /// @notice Action argument defaults
        DEFAULT_TOKEN = address(mockERC20);
        DEFAULT_DEPOSITOR = depositor.addr;
        DEFAULT_RECIPIENT = address(user);
        DEFAULT_THRESHOLD = 0.1 ether;

        DEFAULT_ACTION_ARGS = ISweepDepositAccountERC20Action.SweepDepositAccountERC20({
            token: DEFAULT_TOKEN,
            depositor: DEFAULT_DEPOSITOR,
            recipient: DEFAULT_RECIPIENT,
            threshold: DEFAULT_THRESHOLD,
            fee: DEFAULT_FEE
        });

        DEFAULT_ACTION = address(sweepDepositAccountERC20Action);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice test typical sweep ERC20 flow
    function test_sweepDepositAccountERC20_happyPath() public {
        vm.pauseGasMetering();

        buildInstruction();

        mockERC20.mint(DEFAULT_DEPOSIT_ACCOUNT, DEFAULT_THRESHOLD + 1);

        assertEq(mockERC20.balanceOf(address(user)), USER_START_BALANCE);
        assertEq(mockERC20.balanceOf(address(DEFAULT_DEPOSIT_ACCOUNT)), DEFAULT_THRESHOLD + 1);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(mockERC20.balanceOf(address(user)), USER_START_BALANCE + DEFAULT_THRESHOLD + 1);
        assertEq(mockERC20.balanceOf(address(DEFAULT_DEPOSIT_ACCOUNT)), 0);
    }

    /// @notice test typical sweep ERC20 flow with recipient != user
    function test_sweepDepositAccountERC20_otherRecipient() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.recipient = recipient.addr;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        mockERC20.mint(DEFAULT_DEPOSIT_ACCOUNT, DEFAULT_THRESHOLD + 1);

        assertEq(mockERC20.balanceOf(address(user)), USER_START_BALANCE);
        assertEq(mockERC20.balanceOf(recipient.addr), 0);
        assertEq(mockERC20.balanceOf(address(DEFAULT_DEPOSIT_ACCOUNT)), DEFAULT_THRESHOLD + 1);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(mockERC20.balanceOf(address(user)), USER_START_BALANCE);
        assertEq(mockERC20.balanceOf(recipient.addr), DEFAULT_THRESHOLD + 1);
        assertEq(mockERC20.balanceOf(address(DEFAULT_DEPOSIT_ACCOUNT)), 0);
    }

    /// @notice test typical sweep ERC20 flow when deposit account also has an ETH balance
    function test_sweepDepositAccountERC20_withEthBalance() public {
        vm.pauseGasMetering();

        buildInstruction();

        mockERC20.mint(DEFAULT_DEPOSIT_ACCOUNT, DEFAULT_THRESHOLD + 1);
        vm.deal(DEFAULT_DEPOSIT_ACCOUNT, 100);

        assertEq(mockERC20.balanceOf(address(user)), USER_START_BALANCE);
        assertEq(mockERC20.balanceOf(address(DEFAULT_DEPOSIT_ACCOUNT)), DEFAULT_THRESHOLD + 1);
        assertEq(DEFAULT_DEPOSIT_ACCOUNT.balance, 100);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(mockERC20.balanceOf(address(user)), USER_START_BALANCE + DEFAULT_THRESHOLD + 1);
        assertEq(mockERC20.balanceOf(address(DEFAULT_DEPOSIT_ACCOUNT)), 0);
        assertEq(DEFAULT_DEPOSIT_ACCOUNT.balance, 100);
    }

    /// @notice test Action reverts when depositor is the zero address
    function test_sweepDepositAccountERC20_depositorZero() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.depositor = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test Action reverts when recipient is the zero address
    function test_sweepDepositAccountERC20_recipientZero() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.recipient = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test Action reverts when the deposit account has a balance below the threshold
    function test_sweepDepositAccountERC20_balanceUnderThreshold() public {
        vm.pauseGasMetering();

        buildInstruction();

        mockERC20.mint(DEFAULT_DEPOSIT_ACCOUNT, DEFAULT_THRESHOLD - 1);

        bytes memory result = abi.encodeWithSelector(BalanceUnderThreshold.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test Action still works if the deposit account is somehow already deployed
    function test_sweepDepositAccountERC20_alreadyDeployed() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.prank(address(user));
        DepositAccount depositAccount = new DepositAccount();

        vm.etch(DEFAULT_DEPOSIT_ACCOUNT, address(depositAccount).code);

        mockERC20.mint(DEFAULT_DEPOSIT_ACCOUNT, DEFAULT_THRESHOLD + 1);

        assertEq(mockERC20.balanceOf(address(user)), USER_START_BALANCE);
        assertEq(mockERC20.balanceOf(address(DEFAULT_DEPOSIT_ACCOUNT)), DEFAULT_THRESHOLD + 1);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(mockERC20.balanceOf(address(user)), USER_START_BALANCE + DEFAULT_THRESHOLD + 1);
        assertEq(mockERC20.balanceOf(address(DEFAULT_DEPOSIT_ACCOUNT)), 0);
    }
}
