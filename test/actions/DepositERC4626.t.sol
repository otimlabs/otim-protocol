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

import {IDepositERC4626Action} from "../../src/actions/interfaces/IDepositERC4626Action.sol";
import {DepositERC4626Action} from "../../src/actions/DepositERC4626Action.sol";

import "../../src/actions/errors/Errors.sol";

contract DepositERC4626Test is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    DepositERC4626Action public depositERC4626 = new DepositERC4626Action(address(0), address(0), 0);

    ERC4626Mock public mockVault = new ERC4626Mock(IERC20(MAINNET_USDC));

    address public DEFAULT_VAULT = address(MAINNET_STEAKHOUSE_USDC_VAULT);
    uint256 public DEFAULT_VALUE = 100e6;
    uint256 public DEFAULT_MIN_TOTAL_ASSETS = 100e6;

    IInterval.Schedule public DEFAULT_SCHEDULE;
    IOtimFee.Fee public DEFAULT_FEE;

    IDepositERC4626Action.DepositERC4626 public DEFAULT_ACTION_ARGS;

    constructor() {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", vm.rpcUrl("mainnet"));
        vm.createSelectFork(rpcUrl);

        USER_START_BALANCE = 100_000e6;

        actionManager.addAction(address(depositERC4626));

        DEFAULT_ACTION_ARGS = IDepositERC4626Action.DepositERC4626({
            vault: DEFAULT_VAULT,
            value: DEFAULT_VALUE,
            minTotalAssets: DEFAULT_MIN_TOTAL_ASSETS,
            schedule: DEFAULT_SCHEDULE,
            fee: DEFAULT_FEE
        });

        DEFAULT_ACTION = address(depositERC4626);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice typical Transfer flow with ERC20 token
    function test_depositERC4626_happyPath() public {
        buildInstruction();

        vm.startPrank(MAINNET_USDC_WHALE);
        IERC20(MAINNET_USDC).transfer(address(user), USER_START_BALANCE);
        vm.stopPrank();

        assertEq(IERC20(MAINNET_USDC).balanceOf(address(user)), USER_START_BALANCE);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(IERC20(MAINNET_USDC).balanceOf(address(user)), USER_START_BALANCE - DEFAULT_VALUE);
    }

    /// @notice typical deposit flow when max deposit is reached
    function test_depositERC4626_maxDepositReached() public {
        mockVault.setMaxDeposit(DEFAULT_VALUE - 1);
        mockVault.setTotalAssets(DEFAULT_MIN_TOTAL_ASSETS + 1);

        DEFAULT_ACTION_ARGS.vault = address(mockVault);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.startPrank(MAINNET_USDC_WHALE);
        IERC20(MAINNET_USDC).transfer(address(user), USER_START_BALANCE);
        vm.stopPrank();

        vm.expectEmit();
        emit IDepositERC4626Action.MaxDepositReached(DEFAULT_VALUE - 1);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertEq(IERC20(MAINNET_USDC).balanceOf(address(user)), USER_START_BALANCE - (DEFAULT_VALUE - 1));
    }

    /// @notice test that validation fails with vault == address(0)
    function test_depositERC4626_vaultZero() public {
        DEFAULT_ACTION_ARGS.vault = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with zero value
    function test_depositERC4626_valueZero() public {
        DEFAULT_ACTION_ARGS.value = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that validation fails with zero min total assets
    function test_depositERC4626_minTotalAssetsZero() public {
        DEFAULT_ACTION_ARGS.minTotalAssets = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with total assets too low
    function test_depositERC4626_totalAssetsTooLow() public {
        mockVault.setTotalAssets(DEFAULT_MIN_TOTAL_ASSETS - 1);
        mockVault.setMaxDeposit(DEFAULT_VALUE + 1);

        vm.startPrank(MAINNET_USDC_WHALE);
        IERC20(MAINNET_USDC).transfer(address(user), USER_START_BALANCE);
        vm.stopPrank();

        DEFAULT_ACTION_ARGS.vault = address(mockVault);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(TotalAssetsTooLow.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with max deposit zero
    function test_depositERC4626_maxDepositZero() public {
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

    /// @notice test that execution reverts with user insufficient balance
    function test_depositERC4626_insufficientBalance() public {
        buildInstruction();

        bytes memory result = abi.encodeWithSelector(InsufficientBalance.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
