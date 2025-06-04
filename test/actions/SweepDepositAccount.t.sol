// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/src/Test.sol";
import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";
import {InstructionForkTestContext} from "../utils/InstructionForkTestContext.sol";

import {DrainGasTarget} from "../mocks/DrainGasTarget.sol";
import {RevertTarget} from "../mocks/RevertTarget.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {FeeTokenRegistry} from "../../src/infrastructure/FeeTokenRegistry.sol";
import {Treasury} from "../../src/infrastructure/Treasury.sol";

import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {ISweepDepositAccountAction} from "../../src/actions/interfaces/ISweepDepositAccountAction.sol";
import {SweepDepositAccountAction} from "../../src/actions/SweepDepositAccountAction.sol";

import {DepositAccount} from "../../src/actions/transient-contracts/DepositAccount.sol";

import "../../src/actions/errors/Errors.sol";

contract SweepDepositAccountTest is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    VmSafe.Wallet public depositor;
    VmSafe.Wallet public recipient;

    SweepDepositAccountAction public sweepDepositAccountAction;

    address public DEFAULT_DEPOSIT_ACCOUNT;

    address public DEFAULT_DEPOSITOR;
    address payable public DEFAULT_RECIPIENT;
    uint256 public DEFAULT_THRESHOLD;

    IOtimFee.Fee public DEFAULT_FEE;

    ISweepDepositAccountAction.SweepDepositAccount public DEFAULT_ACTION_ARGS;

    constructor() {
        depositor = vm.createWallet("depositor");
        recipient = vm.createWallet("recipient");

        /// @notice Action setup
        sweepDepositAccountAction = new SweepDepositAccountAction(address(0), address(0), 0);

        actionManager.addAction(address(sweepDepositAccountAction));

        /// @notice calculate the deposit account address
        DEFAULT_DEPOSIT_ACCOUNT = sweepDepositAccountAction.calculateDepositAddress(address(user), depositor.addr);

        /// @notice Action argument defaults
        DEFAULT_DEPOSITOR = depositor.addr;
        DEFAULT_RECIPIENT = payable(address(user));
        DEFAULT_THRESHOLD = 0.1 ether;

        DEFAULT_ACTION_ARGS = ISweepDepositAccountAction.SweepDepositAccount({
            depositor: DEFAULT_DEPOSITOR,
            recipient: DEFAULT_RECIPIENT,
            threshold: DEFAULT_THRESHOLD,
            fee: DEFAULT_FEE
        });

        DEFAULT_ACTION = address(sweepDepositAccountAction);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice test typical sweep flow
    function test_sweepDepositAccount_happyPath() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.deal(DEFAULT_DEPOSIT_ACCOUNT, DEFAULT_THRESHOLD + 1);

        assertEq(address(user).balance, USER_START_BALANCE);
        assertEq(DEFAULT_DEPOSIT_ACCOUNT.balance, DEFAULT_THRESHOLD + 1);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(address(user).balance, USER_START_BALANCE + DEFAULT_THRESHOLD + 1);
        assertEq(DEFAULT_DEPOSIT_ACCOUNT.balance, 0);
    }

    /// @notice test typical sweep flow with recipient != user
    function test_sweepDepositAccount_otherRecipient() public {
        vm.pauseGasMetering();

        // set a recipient other than the user/owner
        DEFAULT_ACTION_ARGS.recipient = payable(recipient.addr);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.deal(DEFAULT_DEPOSIT_ACCOUNT, DEFAULT_THRESHOLD + 1);

        assertEq(address(user).balance, USER_START_BALANCE);
        assertEq(recipient.addr.balance, 0);
        assertEq(DEFAULT_DEPOSIT_ACCOUNT.balance, DEFAULT_THRESHOLD + 1);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(DEFAULT_DEPOSIT_ACCOUNT.balance, 0);
        assertEq(recipient.addr.balance, DEFAULT_THRESHOLD + 1);
    }

    /// @notice test Action reverts if the depositor is the zero address
    function test_sweepDepositAccount_depositorZero() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.depositor = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test Action reverts if the recipient is the zero address
    function test_sweepDepositAccount_recipientZero() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.recipient = payable(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test Action reverts if the deposit account balance is below the threshold
    function test_sweepDepositAccount_balanceUnderThreshold() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.deal(DEFAULT_DEPOSIT_ACCOUNT, DEFAULT_THRESHOLD - 1);

        bytes memory result = abi.encodeWithSelector(BalanceUnderThreshold.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test Action still succeeds if the deposit account is somehow already deployed
    function test_sweepDepositAccount_alreadyDeployed() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.prank(address(user));
        DepositAccount depositAccount = new DepositAccount();

        vm.etch(DEFAULT_DEPOSIT_ACCOUNT, address(depositAccount).code);

        vm.deal(DEFAULT_DEPOSIT_ACCOUNT, DEFAULT_THRESHOLD + 1);

        assertEq(address(user).balance, USER_START_BALANCE);
        assertEq(DEFAULT_DEPOSIT_ACCOUNT.balance, DEFAULT_THRESHOLD + 1);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(address(user).balance, USER_START_BALANCE + DEFAULT_THRESHOLD + 1);
        assertEq(DEFAULT_DEPOSIT_ACCOUNT.balance, 0);
    }

    /// @notice test Action succeeds even with a malicious recipient
    function test_sweepDepositAccount_revertRecipient() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.recipient = payable(address(new RevertTarget()));

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.deal(DEFAULT_DEPOSIT_ACCOUNT, DEFAULT_THRESHOLD + 1);

        assertEq(DEFAULT_ACTION_ARGS.recipient.balance, 0);
        assertEq(DEFAULT_DEPOSIT_ACCOUNT.balance, DEFAULT_THRESHOLD + 1);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(DEFAULT_ACTION_ARGS.recipient.balance, DEFAULT_THRESHOLD + 1);
        assertEq(DEFAULT_DEPOSIT_ACCOUNT.balance, 0);
    }

    /// @notice test Action succeeds even with a malicious recipient
    function test_sweepDepositAccount_drainGasRecipient() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.recipient = payable(address(new DrainGasTarget()));

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.deal(DEFAULT_DEPOSIT_ACCOUNT, DEFAULT_THRESHOLD + 1);

        assertEq(DEFAULT_ACTION_ARGS.recipient.balance, 0);
        assertEq(DEFAULT_DEPOSIT_ACCOUNT.balance, DEFAULT_THRESHOLD + 1);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(DEFAULT_ACTION_ARGS.recipient.balance, DEFAULT_THRESHOLD + 1);
        assertEq(DEFAULT_DEPOSIT_ACCOUNT.balance, 0);
    }
}
