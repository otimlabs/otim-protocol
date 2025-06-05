// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {ERC20Mock} from "../mocks/ERC20Mock.sol";

import {InstructionTestContext} from "../utils/InstructionTestContext.sol";

import {BadERC20Mock} from "../mocks/BadERC20.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {IInterval} from "../../src/actions/schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {ITransferERC20Action} from "../../src/actions/interfaces/ITransferERC20Action.sol";
import {TransferERC20Action} from "../../src/actions/TransferERC20Action.sol";

import "../../src/actions/errors/Errors.sol";

contract TransferERC20Test is InstructionTestContext {
    using SafeERC20 for IERC20;
    using InstructionLib for InstructionLib.Instruction;

    ERC20Mock public USDC = new ERC20Mock();

    TransferERC20Action public transferERC20 = new TransferERC20Action(address(0), address(0), 0);

    /// @notice test Transfer target
    VmSafe.Wallet public target = vm.createWallet("target");

    /// @notice user and target starting balances
    uint256 public TARGET_START_BALANCE;

    /// @notice default Action arguments
    address public DEFAULT_TOKEN = address(USDC);
    address public DEFAULT_TARGET = target.addr;
    uint256 public DEFAULT_VALUE = 100;

    uint256 DEFAULT_START_AT;
    uint256 DEFAULT_START_BY;
    uint256 DEFAULT_INTERVAL;
    uint256 DEFAULT_TIMEOUT;
    IInterval.Schedule public DEFAULT_SCHEDULE;

    IOtimFee.Fee public DEFAULT_FEE;

    ITransferERC20Action.TransferERC20 public DEFAULT_ACTION_ARGS;

    constructor() {
        /// @notice Action setup
        actionManager.addAction(address(transferERC20));

        /// @notice Schedule defaults
        DEFAULT_START_AT = block.timestamp - 1;
        DEFAULT_START_BY = block.timestamp + 10000;
        DEFAULT_INTERVAL = 36000;
        DEFAULT_TIMEOUT = 36000;
        DEFAULT_SCHEDULE = IInterval.Schedule({
            startAt: DEFAULT_START_AT,
            startBy: DEFAULT_START_BY,
            interval: DEFAULT_INTERVAL,
            timeout: DEFAULT_TIMEOUT
        });

        DEFAULT_ACTION_ARGS = ITransferERC20Action.TransferERC20({
            token: DEFAULT_TOKEN,
            target: DEFAULT_TARGET,
            value: DEFAULT_VALUE,
            schedule: DEFAULT_SCHEDULE,
            fee: DEFAULT_FEE
        });

        /// @notice Instruction defaults
        DEFAULT_ACTION = address(transferERC20);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical Transfer flow with ERC20 token
    function test_transferERC20_happyPath() public {
        vm.pauseGasMetering();

        buildInstruction();

        USDC.mint(address(user), USER_START_BALANCE);

        assertEq(USDC.balanceOf(address(user)), USER_START_BALANCE);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(USDC.balanceOf(address(user)), USER_START_BALANCE - DEFAULT_VALUE);
        assertEq(USDC.balanceOf(target.addr), DEFAULT_VALUE);
    }

    /// @notice test that validation fails with token == address(0)
    function test_transferERC20_tokenZero() public {
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

    /// @notice test that validation fails with target == address(0)
    function test_transferERC20_targetZero() public {
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

    /// @notice test that validation fails with zero value
    function test_transferERC20_valueZero() public {
        vm.pauseGasMetering();

        // keep defaults but set value to 0
        DEFAULT_ACTION_ARGS.value = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with user insufficient balance
    function test_transferERC20_insufficientBalance() public {
        vm.pauseGasMetering();

        buildInstruction();

        USDC.mint(target.addr, TARGET_START_BALANCE);

        bytes memory result = abi.encodeWithSelector(InsufficientBalance.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that a failed token transfer reverts
    function test_transferERC20_tokenTransferRevert() public {
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
