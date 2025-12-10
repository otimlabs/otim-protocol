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

import {IInterval} from "../../src/actions/schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {ITransferCCTPV2Action} from "../../src/actions/interfaces/ITransferCCTPV2Action.sol";
import {TransferCCTPV2Action} from "../../src/actions/TransferCCTPV2Action.sol";

import "../../src/actions/errors/Errors.sol";

interface ITokenMessenger {
    function remoteTokenMessengers(uint32 destinationDomain) external returns (bytes32 destinationTokenMessenger);
}

contract TransferCCTPV2Test is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    TransferCCTPV2Action public transferCCTPV2Action;

    uint32 public DEFAULT_DESTINATION_DOMAIN = 2;  // OP Sepolia

    bytes32 public DEFAULT_DESTINATION_TOKEN_MESSENGER;

    uint256 public DEFAULT_AMOUNT = 100e6;

    IInterval.Schedule public DEFAULT_SCHEDULE;
    IOtimFee.Fee public DEFAULT_FEE;

    ITransferCCTPV2Action.TransferCCTPV2 public DEFAULT_ACTION_ARGS = ITransferCCTPV2Action.TransferCCTPV2({
        token: SEPOLIA_USDC,
        amount: DEFAULT_AMOUNT,
        destinationDomain: DEFAULT_DESTINATION_DOMAIN,
        destinationMintRecipient: bytes32(uint256(1)),
        destinationCaller: bytes32(0),
        maxFee: 1e6,
        transferSpeed: ITransferCCTPV2Action.TransferSpeed.FAST,
        schedule: DEFAULT_SCHEDULE,
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

        transferCCTPV2Action = new TransferCCTPV2Action(
            SEPOLIA_TOKEN_MESSENGER_V2, SEPOLIA_TOKEN_MINTER_V2, address(0), address(0), 0
        );

        actionManager.addAction(address(transferCCTPV2Action));

        // Get the destination token messenger for Base Sepolia (domain 6)
        // Note: In V2, this returns the TokenMessenger address, not a separate remote address
        DEFAULT_DESTINATION_TOKEN_MESSENGER = bytes32(uint256(uint160(SEPOLIA_TOKEN_MESSENGER_V2)));

        USER_START_BALANCE = 5_000_000e6;

        DEFAULT_ACTION = address(transferCCTPV2Action);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice test that transferring USDC via CCTP V2 with fast transfer works as expected
    function test_transferCCTPV2_fastTransfer() public {
        buildInstruction();

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), USER_START_BALANCE);
        vm.stopPrank();

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user's balance is equal to the starting balance minus the amount
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(address(user)), USER_START_BALANCE - DEFAULT_AMOUNT);
    }

    /// @notice test that transferring USDC via CCTP V2 with standard transfer works as expected
    function test_transferCCTPV2_standardTransfer() public {
        DEFAULT_ACTION_ARGS.transferSpeed = ITransferCCTPV2Action.TransferSpeed.STANDARD;
        DEFAULT_ACTION_ARGS.maxFee = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), USER_START_BALANCE);
        vm.stopPrank();

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user's balance is equal to the starting balance minus the amount
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(address(user)), USER_START_BALANCE - DEFAULT_AMOUNT);
    }

    /// @notice test that transferring USDC via CCTP V2 with destinationCaller works as expected
    function test_transferCCTPV2_withDestinationCaller() public {
        DEFAULT_ACTION_ARGS.destinationCaller = bytes32(uint256(0x123));

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), USER_START_BALANCE);
        vm.stopPrank();

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user's balance is equal to the starting balance minus the amount
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(address(user)), USER_START_BALANCE - DEFAULT_AMOUNT);
    }

    /// @notice test that transferring USDC via CCTP V2 works as expected even when the user has more USDC than the burn limit
    function test_transferCCTPV2_overBurnLimit() public {
        uint256 burnLimitPerMessage = ITokenController(SEPOLIA_TOKEN_MINTER_V2).burnLimitsPerMessage(SEPOLIA_USDC);

        DEFAULT_ACTION_ARGS.amount = burnLimitPerMessage * 3;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), USER_START_BALANCE);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit ITransferCCTPV2Action.CCTPBurnLimitReached(SEPOLIA_USDC, burnLimitPerMessage);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user's balance is equal to the starting balance minus the burn limit per message
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(address(user)), USER_START_BALANCE - burnLimitPerMessage);
    }

    /// @notice test that the Instruction reverts when the token is set to the zero address
    function test_transferCCTPV2_tokenZero() public {
        DEFAULT_ACTION_ARGS.token = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction reverts when the destinationMintRecipient is set to the zero address
    function test_transferCCTPV2_destinationMintRecipientZero() public {
        DEFAULT_ACTION_ARGS.destinationMintRecipient = bytes32(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction reverts when the amount is zero
    function test_transferCCTPV2_amountZero() public {
        DEFAULT_ACTION_ARGS.amount = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction reverts when the account balance is below the amount
    function test_transferCCTPV2_insufficientBalance() public {
        buildInstruction();

        // set the deposit account balance to below the amount
        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), DEFAULT_AMOUNT - 1);
        vm.stopPrank();

        bytes memory result = abi.encodeWithSelector(InsufficientBalance.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction reverts when the CCTP token is not supported
    function test_transferCCTPV2_tokenNotSupported() public {
        DEFAULT_ACTION_ARGS.token = SEPOLIA_WETH9;

        vm.deal(address(user), USER_START_BALANCE);
        vm.prank(address(user));
        IWETH9(SEPOLIA_WETH9).deposit{value: USER_START_BALANCE}();

        assertEq(IWETH9(SEPOLIA_WETH9).balanceOf(address(user)), USER_START_BALANCE);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(CCTPTokenNotSupported.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}

