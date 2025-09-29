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

import {ISweepDepositERC4626Action} from "../../src/actions/interfaces/ISweepDepositERC4626Action.sol";
import {SweepDepositERC4626Action} from "../../src/actions/SweepDepositERC4626Action.sol";

import "../../src/actions/errors/Errors.sol";

contract SweepDepositERC4626Test is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    SweepDepositERC4626Action public sweepDepositERC4626 = new SweepDepositERC4626Action(address(0), address(0), 0);

    ERC4626Mock public mockVault = new ERC4626Mock(IERC20(MAINNET_USDC));

    address public DEFAULT_VAULT = address(MAINNET_STEAKHOUSE_USDC_VAULT);
    uint256 public DEFAULT_THRESHOLD = 100e6;
    uint256 public DEFAULT_END_BALANCE = 0;
    uint256 public DEFAULT_MIN_TOTAL_ASSETS = 100e6;

    IOtimFee.Fee public DEFAULT_FEE;

    ISweepDepositERC4626Action.SweepDepositERC4626 public DEFAULT_ACTION_ARGS;

    constructor() {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", vm.rpcUrl("mainnet"));
        vm.createSelectFork(rpcUrl);

        USER_START_BALANCE = 100_000e6;

        actionManager.addAction(address(sweepDepositERC4626));

        DEFAULT_ACTION_ARGS = ISweepDepositERC4626Action.SweepDepositERC4626({
            vault: DEFAULT_VAULT,
            threshold: DEFAULT_THRESHOLD,
            endBalance: DEFAULT_END_BALANCE,
            minTotalAssets: DEFAULT_MIN_TOTAL_ASSETS,
            fee: DEFAULT_FEE
        });

        DEFAULT_ACTION = address(sweepDepositERC4626);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical Transfer flow with ERC20 token
    function test_sweepDepositERC4626_happyPath() public {
        vm.startPrank(MAINNET_USDC_WHALE);
        IERC20(MAINNET_USDC).transfer(address(user), USER_START_BALANCE);
        vm.stopPrank();

        buildInstruction();

        // don't check number of shares emitted
        vm.expectEmit(true, true, true, false);
        emit IERC4626.Deposit(address(user), address(user), USER_START_BALANCE, 0);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(IERC20(MAINNET_USDC).balanceOf(address(user)), DEFAULT_END_BALANCE);
    }

    /// @notice typical deposit flow when max deposit is reached
    function test_depositERC4626_maxDepositReached() public {
        vm.startPrank(MAINNET_USDC_WHALE);
        IERC20(MAINNET_USDC).transfer(address(user), USER_START_BALANCE);
        vm.stopPrank();

        mockVault.setMaxDeposit(USER_START_BALANCE - DEFAULT_END_BALANCE - 1);
        mockVault.setTotalAssets(DEFAULT_MIN_TOTAL_ASSETS + 1);

        DEFAULT_ACTION_ARGS.vault = address(mockVault);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit ISweepDepositERC4626Action.MaxDepositReached(USER_START_BALANCE - DEFAULT_END_BALANCE - 1);

        // don't check number of shares emitted
        vm.expectEmit(true, true, true, false);
        emit IERC4626.Deposit(address(user), address(user), USER_START_BALANCE - mockVault.maxDeposit(address(user)), 0);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(
            IERC20(MAINNET_USDC).balanceOf(address(user)), USER_START_BALANCE - mockVault.maxDeposit(address(user))
        );
    }

    /// @notice test that validation fails with vault == address(0)
    function test_sweepDepositERC4626_vaultZero() public {
        DEFAULT_ACTION_ARGS.vault = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with zero value
    function test_sweepDepositERC4626_endBalanceOverThreshold() public {
        DEFAULT_ACTION_ARGS.endBalance = DEFAULT_THRESHOLD + 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with balance under threshold
    function test_sweepDepositERC4626_balanceUnderThreshold() public {
        vm.startPrank(MAINNET_USDC_WHALE);
        IERC20(MAINNET_USDC).transfer(address(user), DEFAULT_THRESHOLD - 1);
        vm.stopPrank();

        buildInstruction();

        assertEq(IERC20(MAINNET_USDC).balanceOf(address(user)), DEFAULT_THRESHOLD - 1);

        bytes memory result = abi.encodeWithSelector(BalanceUnderThreshold.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with zero min total assets
    function test_sweepDepositERC4626_minTotalAssetsZero() public {
        DEFAULT_ACTION_ARGS.minTotalAssets = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with max deposit zero
    function test_sweepDepositERC4626_maxDepositZero() public {
        vm.startPrank(MAINNET_USDC_WHALE);
        IERC20(MAINNET_USDC).transfer(address(user), USER_START_BALANCE);
        vm.stopPrank();

        mockVault.setTotalAssets(DEFAULT_MIN_TOTAL_ASSETS + 1);
        mockVault.setMaxDeposit(0);

        DEFAULT_ACTION_ARGS.vault = address(mockVault);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(MaxDepositZero.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with total assets too low
    function test_sweepDepositERC4626_totalAssetsTooLow() public {
        vm.startPrank(MAINNET_USDC_WHALE);
        IERC20(MAINNET_USDC).transfer(address(user), USER_START_BALANCE);
        vm.stopPrank();

        mockVault.setTotalAssets(DEFAULT_MIN_TOTAL_ASSETS - 1);
        mockVault.setMaxDeposit(DEFAULT_THRESHOLD + 1);

        DEFAULT_ACTION_ARGS.vault = address(mockVault);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(TotalAssetsTooLow.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
