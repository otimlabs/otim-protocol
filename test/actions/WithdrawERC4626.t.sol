// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {VmSafe} from "forge-std/src/Vm.sol";

import {InstructionForkTestContext} from "../utils/InstructionForkTestContext.sol";

import {IERC4626} from "@openzeppelin-contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ERC4626Mock} from "../mocks/ERC4626Mock.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {IInterval} from "../../src/actions/schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {IWithdrawERC4626Action} from "../../src/actions/interfaces/IWithdrawERC4626Action.sol";
import {WithdrawERC4626Action} from "../../src/actions/WithdrawERC4626Action.sol";

import "../../src/actions/errors/Errors.sol";

contract WithdrawERC4626Test is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    WithdrawERC4626Action public withdrawERC4626 = new WithdrawERC4626Action(address(0), address(0), 0);

    ERC4626Mock public mockVault = new ERC4626Mock(IERC20(MAINNET_USDC));

    address public DEFAULT_VAULT = address(MAINNET_STEAKHOUSE_USDC_VAULT);
    address public DEFAULT_RECIPIENT = address(user);
    uint256 public DEFAULT_VALUE = 100e6;
    uint256 public DEFAULT_MIN_TOTAL_SHARES = 100e6;

    IInterval.Schedule public DEFAULT_SCHEDULE;
    IOtimFee.Fee public DEFAULT_FEE;

    IWithdrawERC4626Action.WithdrawERC4626 public DEFAULT_ACTION_ARGS;

    constructor() {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", vm.rpcUrl("mainnet"));
        vm.createSelectFork(rpcUrl);

        USER_START_BALANCE = 100_000e6;

        actionManager.addAction(address(withdrawERC4626));

        DEFAULT_ACTION_ARGS = IWithdrawERC4626Action.WithdrawERC4626({
            recipient: DEFAULT_RECIPIENT,
            vault: DEFAULT_VAULT,
            value: DEFAULT_VALUE,
            minTotalShares: DEFAULT_MIN_TOTAL_SHARES,
            schedule: DEFAULT_SCHEDULE,
            fee: DEFAULT_FEE
        });

        DEFAULT_ACTION = address(withdrawERC4626);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical WithdrawERC4626 flow
    function test_withdrawERC4626_happyPath() public {
        vm.startPrank(MAINNET_USDC_WHALE);
        IERC20(MAINNET_USDC).approve(DEFAULT_VAULT, USER_START_BALANCE);
        IERC4626(DEFAULT_VAULT).deposit(USER_START_BALANCE, address(user));
        vm.stopPrank();

        buildInstruction();

        vm.expectEmit(true, true, true, false);
        emit IERC4626.Withdraw(address(user), DEFAULT_RECIPIENT, address(user), DEFAULT_VALUE, 0);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(IERC20(MAINNET_USDC).balanceOf(address(user)), DEFAULT_VALUE);
    }

    /// @notice typical WithdrawERC4626 flow when max withdraw is reached
    function test_withdrawERC4626_maxWithdrawReached() public {
        vm.startPrank(MAINNET_USDC_WHALE);
        IERC20(MAINNET_USDC).approve(address(mockVault), USER_START_BALANCE);
        mockVault.deposit(USER_START_BALANCE, address(user));
        vm.stopPrank();

        uint256 maxWithdraw = DEFAULT_VALUE - 1;

        mockVault.setMaxWithdraw(maxWithdraw);
        mockVault.setTotalSupply(DEFAULT_MIN_TOTAL_SHARES + 1);

        DEFAULT_ACTION_ARGS.vault = address(mockVault);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit IWithdrawERC4626Action.MaxWithdrawReached(maxWithdraw);

        vm.expectEmit(true, true, true, false);
        emit IERC4626.Withdraw(address(user), DEFAULT_RECIPIENT, address(user), maxWithdraw, 0);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(IERC20(MAINNET_USDC).balanceOf(address(user)), maxWithdraw);
    }

    /// @notice test that validation fails with vault == address(0)
    function test_withdrawERC4626_vaultZero() public {
        DEFAULT_ACTION_ARGS.vault = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with recipient == address(0)
    function test_withdrawERC4626_recipientZero() public {
        DEFAULT_ACTION_ARGS.recipient = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with zero value
    function test_withdrawERC4626_valueZero() public {
        DEFAULT_ACTION_ARGS.value = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with zero min total shares
    function test_withdrawERC4626_minTotalSharesZero() public {
        DEFAULT_ACTION_ARGS.minTotalShares = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with max withdraw zero
    function test_withdrawERC4626_maxWithdrawZero() public {
        mockVault.setTotalSupply(DEFAULT_MIN_TOTAL_SHARES + 1);
        mockVault.setMaxWithdraw(0);

        DEFAULT_ACTION_ARGS.vault = address(mockVault);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(MaxWithdrawZero.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with total shares too low
    function test_withdrawERC4626_totalSharesTooLow() public {
        vm.startPrank(MAINNET_USDC_WHALE);
        IERC20(MAINNET_USDC).approve(address(mockVault), USER_START_BALANCE);
        mockVault.deposit(USER_START_BALANCE, address(user));
        vm.stopPrank();

        mockVault.setTotalSupply(DEFAULT_MIN_TOTAL_SHARES - 1);

        DEFAULT_ACTION_ARGS.vault = address(mockVault);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(TotalSharesTooLow.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
