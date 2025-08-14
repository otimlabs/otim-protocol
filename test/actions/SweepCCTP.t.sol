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

import {ISweepCCTPAction} from "../../src/actions/interfaces/ISweepCCTPAction.sol";
import {SweepCCTPAction} from "../../src/actions/SweepCCTPAction.sol";

import "../../src/actions/errors/Errors.sol";

interface ITokenMessenger {
    function remoteTokenMessengers(uint32 destinationDomain) external returns (bytes32 destinationTokenMessenger);
}

contract SweepCCTPTest is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    address public constant SEPOLIA_TOKEN_MESSENGER = address(0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5);
    address public constant SEPOLIA_TOKEN_MINTER = address(0xE997d7d2F6E065a9A93Fa2175E878Fb9081F1f0A);

    address public constant SEPOLIA_USDC = address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
    address public constant SEPOLIA_WETH9 = address(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);

    address public constant SEPOLIA_USDC_WHALE = address(0x1fD9611f009fcB8Bec0A4854FDcA0832DfdB04E3);

    SweepCCTPAction public sweepCCTPAction;

    uint32 public DEFAULT_DESTINATION_DOMAIN = 4;

    bytes32 public DEFAULT_DESTINATION_TOKEN_MESSENGER;

    uint256 public DEFAULT_THRESHOLD = 100e6;
    uint256 public DEFAULT_END_BALANCE = 50e6;

    IOtimFee.Fee public DEFAULT_FEE;

    ISweepCCTPAction.SweepCCTP public DEFAULT_ACTION_ARGS = ISweepCCTPAction.SweepCCTP({
        token: SEPOLIA_USDC,
        destinationDomain: DEFAULT_DESTINATION_DOMAIN,
        destinationMintRecipient: bytes32(uint256(1)),
        threshold: DEFAULT_THRESHOLD,
        endBalance: DEFAULT_END_BALANCE,
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
        bytes32 destinationCaller
    );

    constructor() {
        string memory rpcUrl = vm.envOr("SEPOLIA_RPC_URL", string("https://ethereum-sepolia-rpc.publicnode.com"));

        vm.createSelectFork(rpcUrl);

        sweepCCTPAction = new SweepCCTPAction(SEPOLIA_TOKEN_MESSENGER, SEPOLIA_TOKEN_MINTER, address(0), address(0), 0);

        actionManager.addAction(address(sweepCCTPAction));

        DEFAULT_DESTINATION_TOKEN_MESSENGER =
            ITokenMessenger(SEPOLIA_TOKEN_MESSENGER).remoteTokenMessengers(DEFAULT_DESTINATION_DOMAIN);

        DEFAULT_ACTION = address(sweepCCTPAction);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice test that sweeping USDC via CCTP works as expected
    function test_sweepCCTP_happyPath() public {
        buildInstruction();

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), DEFAULT_THRESHOLD + 1);
        vm.stopPrank();

        // check that the CCTP transfer was initiated correctly
        // don't check the nonce
        vm.expectEmit(false, true, true, true);
        emit DepositForBurn(
            0,
            SEPOLIA_USDC,
            DEFAULT_THRESHOLD + 1 - DEFAULT_END_BALANCE,
            address(user),
            bytes32(uint256(1)),
            DEFAULT_DESTINATION_DOMAIN,
            DEFAULT_DESTINATION_TOKEN_MESSENGER,
            bytes32(uint256(0))
        );

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user's balance is equal to endBalance after the sweep
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(address(user)), DEFAULT_END_BALANCE);
    }

    /// @notice test the special case for sweeping the entire balance (threshold == endBalance == 0)
    function test_sweepCCTP_happyPath_sweepEntireBalance() public {
        DEFAULT_ACTION_ARGS.threshold = 0;
        DEFAULT_ACTION_ARGS.endBalance = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), DEFAULT_THRESHOLD);
        vm.stopPrank();

        // check that the CCTP transfer was initiated correctly
        // don't check the nonce
        vm.expectEmit(false, true, true, true);
        emit DepositForBurn(
            0,
            SEPOLIA_USDC,
            DEFAULT_THRESHOLD,
            address(user),
            bytes32(uint256(1)),
            DEFAULT_DESTINATION_DOMAIN,
            DEFAULT_DESTINATION_TOKEN_MESSENGER,
            bytes32(uint256(0))
        );

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user's balance is equal to 0 after the sweep
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(address(user)), 0);
    }

    /// @notice test that sweeping USDC via CCTP works as expected even when the user has more USDC than the burn limit
    function test_sweepCCTP_happyPath_overBurnLimit() public {
        buildInstruction();

        uint256 maxBurnPerMessage = ITokenController(SEPOLIA_TOKEN_MINTER).burnLimitsPerMessage(SEPOLIA_USDC);

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), maxBurnPerMessage * 3);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit ISweepCCTPAction.CCTPBurnLimitReached(SEPOLIA_USDC, maxBurnPerMessage);

        // check that the CCTP transfer was initiated correctly
        // don't check the nonce
        vm.expectEmit(false, true, true, true);
        emit DepositForBurn(
            0,
            SEPOLIA_USDC,
            maxBurnPerMessage,
            address(user),
            bytes32(uint256(1)),
            DEFAULT_DESTINATION_DOMAIN,
            DEFAULT_DESTINATION_TOKEN_MESSENGER,
            bytes32(uint256(0))
        );

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user's balance is equal to the starting balance minus the burn limit
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(address(user)), maxBurnPerMessage * 2);
    }

    /// @notice test that the Instruction reverts when the token is set to the zero address
    function test_sweepCCTP_tokenZero() public {
        DEFAULT_ACTION_ARGS.token = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction reverts when the destinationMintRecipient is set to the zero address
    function test_sweepCCTP_destinationMintRecipientZero() public {
        DEFAULT_ACTION_ARGS.destinationMintRecipient = bytes32(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction reverts when the endBalance > threshold
    function test_sweepCCTP_endBalanceOverThreshold() public {
        DEFAULT_ACTION_ARGS.endBalance = DEFAULT_THRESHOLD + 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction reverts when the account balance is below the threshold
    function test_sweepCCTP_balanceUnderThreshold() public {
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
    function test_sweepCCTP_tokenNotSupported() public {
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
