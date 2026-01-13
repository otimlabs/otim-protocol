// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/src/Test.sol";
import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IWETH9} from "../../src/actions/external/IWETH9.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";
import {InstructionForkTestContext} from "../utils/InstructionForkTestContext.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {ITokenController} from "../../src/actions/external/ITokenController.sol";

import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {ISweepCCTPV2Action} from "../../src/actions/interfaces/ISweepCCTPV2Action.sol";
import {SweepCCTPV2Action} from "../../src/actions/SweepCCTPV2Action.sol";

import "../../src/actions/errors/Errors.sol";

interface ITokenMessenger {
    function remoteTokenMessengers(uint32 destinationDomain) external returns (bytes32 destinationTokenMessenger);
}

contract SweepCCTPV2Test is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    SweepCCTPV2Action public sweepCCTPV2Action;

    uint32 public DEFAULT_DESTINATION_DOMAIN = 2; // OP Sepolia

    bytes32 public DEFAULT_DESTINATION_TOKEN_MESSENGER;

    uint256 public DEFAULT_THRESHOLD = 100e6;
    uint256 public DEFAULT_END_BALANCE = 50e6;

    IOtimFee.Fee public DEFAULT_FEE;

    ISweepCCTPV2Action.SweepCCTPV2 public DEFAULT_ACTION_ARGS = ISweepCCTPV2Action.SweepCCTPV2({
        token: SEPOLIA_USDC,
        destinationDomain: DEFAULT_DESTINATION_DOMAIN,
        destinationMintRecipient: bytes32(uint256(1)),
        threshold: DEFAULT_THRESHOLD,
        endBalance: DEFAULT_END_BALANCE,
        destinationCaller: bytes32(0),
        maxFee: 1e6,
        minFinalityThreshold: 1000,
        fee: DEFAULT_FEE
    });

    event DepositForBurn(
        uint64 indexed nonce,
        address indexed burnToken,
        uint256 amount,
        address indexed depositor,
        bytes32 mintRecipient,
        uint32 destinationDomain,
        bytes32 destinationTokenMessenger,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    );

    // CCTP V2 emits MessageSent instead of DepositForBurn
    event MessageSent(bytes message);

    constructor() {
        setUpFork();

        sweepCCTPV2Action =
            new SweepCCTPV2Action(SEPOLIA_TOKEN_MESSENGER_V2, SEPOLIA_TOKEN_MINTER_V2, address(0), address(0), 0);

        actionManager.addAction(address(sweepCCTPV2Action));

        // Get the destination token messenger for Base Sepolia (domain 6)
        // Note: In V2, this returns the TokenMessenger address, not a separate remote address
        DEFAULT_DESTINATION_TOKEN_MESSENGER = bytes32(uint256(uint160(SEPOLIA_TOKEN_MESSENGER_V2)));

        DEFAULT_ACTION = address(sweepCCTPV2Action);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice test that sweeping USDC via CCTP V2 with fast transfer works as expected
    function test_sweepCCTPV2_fastTransfer() public {
        buildInstruction();

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), DEFAULT_THRESHOLD + 1);
        vm.stopPrank();

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user's balance is equal to endBalance after the sweep
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(address(user)), DEFAULT_END_BALANCE);
    }

    /// @notice test that sweeping USDC via CCTP V2 with standard transfer works as expected
    function test_sweepCCTPV2_standardTransfer() public {
        DEFAULT_ACTION_ARGS.minFinalityThreshold = 2000;
        DEFAULT_ACTION_ARGS.maxFee = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), DEFAULT_THRESHOLD + 1);
        vm.stopPrank();

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user's balance is equal to endBalance after the sweep
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(address(user)), DEFAULT_END_BALANCE);
    }

    /// @notice test the special case for sweeping the entire balance (threshold == endBalance == 0)
    function test_sweepCCTPV2_sweepEntireBalance() public {
        DEFAULT_ACTION_ARGS.threshold = 0;
        DEFAULT_ACTION_ARGS.endBalance = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), DEFAULT_THRESHOLD);
        vm.stopPrank();

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user's balance is equal to 0 after the sweep
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(address(user)), 0);
    }

    /// @notice test that sweeping USDC via CCTP V2 with destinationCaller works as expected
    function test_sweepCCTPV2_withDestinationCaller() public {
        DEFAULT_ACTION_ARGS.destinationCaller = bytes32(uint256(0x456));

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), DEFAULT_THRESHOLD + 1);
        vm.stopPrank();

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user's balance is equal to endBalance after the sweep
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(address(user)), DEFAULT_END_BALANCE);
    }

    /// @notice test that sweeping USDC via CCTP V2 works as expected even when the user has more USDC than the burn limit
    function test_sweepCCTPV2_overBurnLimit() public {
        buildInstruction();

        uint256 maxBurnPerMessage = ITokenController(SEPOLIA_TOKEN_MINTER_V2).burnLimitsPerMessage(SEPOLIA_USDC);

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), maxBurnPerMessage * 3);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit ISweepCCTPV2Action.CCTPBurnLimitReached(SEPOLIA_USDC, maxBurnPerMessage);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user's balance is equal to the starting balance minus the burn limit
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(address(user)), maxBurnPerMessage * 2);
    }

    /// @notice test that the Instruction reverts when the token is set to the zero address
    function test_sweepCCTPV2_tokenZero() public {
        DEFAULT_ACTION_ARGS.token = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction reverts when the destinationMintRecipient is set to the zero address
    function test_sweepCCTPV2_destinationMintRecipientZero() public {
        DEFAULT_ACTION_ARGS.destinationMintRecipient = bytes32(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction reverts when the endBalance > threshold
    function test_sweepCCTPV2_endBalanceOverThreshold() public {
        DEFAULT_ACTION_ARGS.endBalance = DEFAULT_THRESHOLD + 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction reverts when the account balance is below the threshold
    function test_sweepCCTPV2_balanceUnderThreshold() public {
        buildInstruction();

        // set the deposit account balance to below the threshold
        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), DEFAULT_THRESHOLD - 1);
        vm.stopPrank();

        bytes memory result = abi.encodeWithSelector(BalanceUnderThreshold.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction reverts when the CCTP token is not supported
    function test_sweepCCTPV2_tokenNotSupported() public {
        DEFAULT_ACTION_ARGS.token = SEPOLIA_WETH9;

        vm.deal(address(user), DEFAULT_THRESHOLD + 1);
        vm.prank(address(user));
        IWETH9(SEPOLIA_WETH9).deposit{value: address(user).balance}();

        assertEq(IWETH9(SEPOLIA_WETH9).balanceOf(address(user)), DEFAULT_THRESHOLD + 1);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(CCTPTokenNotSupported.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}

