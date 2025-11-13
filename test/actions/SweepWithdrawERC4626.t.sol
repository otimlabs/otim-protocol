// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {VmSafe} from "forge-std/src/Vm.sol";

import {InstructionForkTestContext} from "../utils/InstructionForkTestContext.sol";

import {IERC4626} from "@openzeppelin-contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ERC4626Mock} from "../mocks/ERC4626Mock.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {ISweepWithdrawERC4626Action} from "../../src/actions/interfaces/ISweepWithdrawERC4626Action.sol";
import {SweepWithdrawERC4626Action} from "../../src/actions/SweepWithdrawERC4626Action.sol";

import "../../src/actions/errors/Errors.sol";

contract SweepWithdrawERC4626Test is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    SweepWithdrawERC4626Action public sweepWithdrawERC4626 = new SweepWithdrawERC4626Action(address(0), address(0), 0);

    ERC4626Mock public mockVault = new ERC4626Mock(IERC20(MAINNET_USDC));

    address public DEFAULT_VAULT = address(MAINNET_STEAKHOUSE_USDC_VAULT);
    address public DEFAULT_RECIPIENT = address(user);
    uint256 public DEFAULT_THRESHOLD = 50e6;
    uint256 public DEFAULT_END_BALANCE = 20e6;

    IOtimFee.Fee public DEFAULT_FEE;

    ISweepWithdrawERC4626Action.SweepWithdrawERC4626 public DEFAULT_ACTION_ARGS;

    constructor() {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", vm.rpcUrl("mainnet"));
        vm.createSelectFork(rpcUrl);

        USER_START_BALANCE = 100_000e6;

        actionManager.addAction(address(sweepWithdrawERC4626));

        DEFAULT_ACTION_ARGS = ISweepWithdrawERC4626Action.SweepWithdrawERC4626({
            vault: DEFAULT_VAULT,
            recipient: DEFAULT_RECIPIENT,
            threshold: DEFAULT_THRESHOLD,
            endBalance: DEFAULT_END_BALANCE,
            fee: DEFAULT_FEE
        });

        DEFAULT_ACTION = address(sweepWithdrawERC4626);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical SweepWithdrawERC4626 flow
    function test_sweepWithdrawERC4626_happyPath() public {
        vm.startPrank(MAINNET_USDC_WHALE);
        IERC20(MAINNET_USDC).approve(DEFAULT_VAULT, USER_START_BALANCE);
        IERC4626(DEFAULT_VAULT).deposit(USER_START_BALANCE, address(user));
        vm.stopPrank();

        buildInstruction();

        vm.expectEmit(true, true, true, false);
        emit IERC4626.Withdraw(
            address(user), DEFAULT_RECIPIENT, address(user), USER_START_BALANCE - DEFAULT_END_BALANCE, 0
        );

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(IERC4626(DEFAULT_VAULT).maxWithdraw(address(user)), DEFAULT_END_BALANCE);
    }

    /// @notice SweepWithdrawERC4626 flow when max withdraw is reached
    function test_sweepWithdrawERC4626_maxWithdrawReached() public {
        vm.startPrank(MAINNET_USDC_WHALE);
        IERC20(MAINNET_USDC).approve(address(mockVault), USER_START_BALANCE);
        mockVault.deposit(USER_START_BALANCE, address(user));
        vm.stopPrank();

        uint256 maxWithdraw = USER_START_BALANCE - DEFAULT_END_BALANCE - 1;

        mockVault.setMaxWithdraw(maxWithdraw);
        /// @dev we have to manually set this because the mock contract has an overridden totalSupply function which is used to calculate convertToAssets
        mockVault.setTotalSupply(USER_START_BALANCE);

        DEFAULT_ACTION_ARGS.vault = address(mockVault);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit ISweepWithdrawERC4626Action.MaxWithdrawReached(maxWithdraw, USER_START_BALANCE - maxWithdraw);

        vm.expectEmit(true, true, true, false);
        emit IERC4626.Withdraw(address(user), DEFAULT_RECIPIENT, address(user), maxWithdraw, 0);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with vault == address(0)
    function test_sweepWithdrawERC4626_vaultZero() public {
        DEFAULT_ACTION_ARGS.vault = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with recipient == address(0)
    function test_sweepWithdrawERC4626_recipientZero() public {
        DEFAULT_ACTION_ARGS.recipient = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with endBalance over threshold
    function test_sweepWithdrawERC4626_endBalanceOverThreshold() public {
        DEFAULT_ACTION_ARGS.endBalance = DEFAULT_THRESHOLD + 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with balance under threshold
    function test_sweepWithdrawERC4626_balanceUnderThreshold() public {
        DEFAULT_ACTION_ARGS.vault = address(mockVault);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(BalanceUnderThreshold.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
