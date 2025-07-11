// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/src/Test.sol";
import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";
import {InstructionForkTestContext} from "../utils/InstructionForkTestContext.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {SkipGoFeeOracle} from "../../src/actions/oracles/SkipGoFeeOracle.sol";
import {ICCTPRelayer} from "@skip-go-evm-contracts/CCTPRelayer/src/interfaces/ICCTPRelayer.sol";
import {ITokenController} from "../../src/actions/external/ITokenController.sol";

import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {IConditionalSkipCCTPTransferAction} from "../../src/actions/interfaces/IConditionalSkipCCTPTransferAction.sol";
import {ConditionalSkipCCTPTransferAction} from "../../src/actions/ConditionalSkipCCTPTransferAction.sol";

import {SkipCCTPDepositAccount} from "../../src/actions/transient-contracts/SkipCCTPDepositAccount.sol";

import "../../src/actions/errors/Errors.sol";

contract ConditionalSkipCCTPTransferTest is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    address public constant SEPOLIA_USDC = address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
    address public constant SEPOLIA_TOKEN_MINTER = address(0xE997d7d2F6E065a9A93Fa2175E878Fb9081F1f0A);
    address public constant SEPOLIA_CCTP_RELAYER = address(0x3cb7630cAdd5bC6Cba3Aa331feb9b3D018A74f83);

    address public constant SEPOLIA_USDC_WHALE = address(0x1fD9611f009fcB8Bec0A4854FDcA0832DfdB04E3);

    SkipGoFeeOracle public skipGoFeeOracle;
    ConditionalSkipCCTPTransferAction public conditionalSkipCCTPTransferAction;

    VmSafe.Wallet public depositor = vm.createWallet("depositor");

    uint256 public constant DEFAULT_SKIP_GO_FEE = 2000;

    address public DEFAULT_DEPOSITOR = depositor.addr;
    uint256 public DEFAULT_THRESHOLD = DEFAULT_SKIP_GO_FEE * 5;

    address public DEFAULT_DEPOSIT_ACCOUNT;

    IOtimFee.Fee public DEFAULT_FEE;

    IConditionalSkipCCTPTransferAction.ConditionalSkipCCTPTransfer public DEFAULT_ACTION_ARGS;

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

        skipGoFeeOracle = new SkipGoFeeOracle(address(this));

        skipGoFeeOracle.setFee(4, DEFAULT_SKIP_GO_FEE);

        conditionalSkipCCTPTransferAction = new ConditionalSkipCCTPTransferAction(
            SEPOLIA_USDC,
            SEPOLIA_CCTP_RELAYER,
            SEPOLIA_TOKEN_MINTER,
            address(skipGoFeeOracle),
            address(0),
            address(0),
            0
        );

        actionManager.addAction(address(conditionalSkipCCTPTransferAction));

        DEFAULT_ACTION_ARGS = IConditionalSkipCCTPTransferAction.ConditionalSkipCCTPTransfer({
            destinationDomain: 4,
            destinationMintRecipient: bytes32(uint256(1)),
            threshold: DEFAULT_THRESHOLD,
            fee: DEFAULT_FEE
        });

        DEFAULT_ACTION = address(conditionalSkipCCTPTransferAction);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice test that sweeping USDC to the CCTP relayer works as expected
    function test_conditionalSkipCCTPTransfer_happyPath() public {
        buildInstruction();

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), DEFAULT_THRESHOLD + 1);
        vm.stopPrank();

        uint256 feeAmount = skipGoFeeOracle.getFee(DEFAULT_ACTION_ARGS.destinationDomain);

        // check that the CCTP transfer was initiated correctly
        // don't check the nonce
        vm.expectEmit(false, true, true, true);
        emit DepositForBurn(
            0,
            SEPOLIA_USDC,
            DEFAULT_THRESHOLD + 1 - feeAmount,
            SEPOLIA_CCTP_RELAYER,
            bytes32(uint256(1)),
            4,
            bytes32(uint256(uint160(address(0x57d4eAf1091577A6b7d121202AFBD2808134F117)))),
            bytes32(uint256(0))
        );

        // check that the Skip Go fee was paid correctly
        // don't check the nonce
        vm.expectEmit(false, true, false, false);
        emit ICCTPRelayer.PaymentForRelay(0, feeAmount);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the deposit account is empty after the sweep
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(DEFAULT_DEPOSIT_ACCOUNT), 0);
    }

    /// @notice test that sweeping USDC to the CCTP relayer works as expected even when the deposit account has more USDC than the burn limit
    function test_conditionalSkipCCTPTransfer_overBurnLimit() public {
        buildInstruction();

        uint256 maxBurnPerMessage = ITokenController(SEPOLIA_TOKEN_MINTER).burnLimitsPerMessage(SEPOLIA_USDC);

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), maxBurnPerMessage * 5);
        vm.stopPrank();

        uint256 feeAmount = skipGoFeeOracle.getFee(DEFAULT_ACTION_ARGS.destinationDomain);

        // check that the CCTP transfer was initiated correctly
        // don't check the nonce
        vm.expectEmit(false, true, true, true);
        emit DepositForBurn(
            0,
            SEPOLIA_USDC,
            maxBurnPerMessage,
            SEPOLIA_CCTP_RELAYER,
            bytes32(uint256(1)),
            4,
            bytes32(uint256(uint160(address(0x57d4eAf1091577A6b7d121202AFBD2808134F117)))),
            bytes32(uint256(0))
        );

        // check that the Skip Go fee was paid correctly
        // don't check the nonce
        vm.expectEmit(false, true, false, false);
        emit ICCTPRelayer.PaymentForRelay(0, feeAmount);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the deposit account was swept up to the max burn limit (minus the fee)
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(address(user)), maxBurnPerMessage * 4 - feeAmount);
    }

    /// @notice test that the Instruction reverts when the destinationMintRecipient is set to the zero address
    function test_conditionalSkipCCTPTransfer_destinationMintRecipientZero() public {
        // set the destinationMintRecipient to the zero address
        DEFAULT_ACTION_ARGS.destinationMintRecipient = bytes32(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction reverts when the deposit account balance is below the threshold
    function test_conditionalSkipCCTPTransfer_balanceUnderThreshold() public {
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

    /// @notice test that the Instruction reverts when the deposit account balance is below the Skip Go fee amount
    function test_conditionalSkipCCTPTransfer_insufficientSkipGoFeeBalance() public {
        // set threshold to zero to avoid the balance under threshold check
        DEFAULT_ACTION_ARGS.threshold = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        uint256 feeAmount = skipGoFeeOracle.getFee(DEFAULT_ACTION_ARGS.destinationDomain);

        // set the deposit account balance to below the Skip Go fee amount
        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), feeAmount - 1);
        vm.stopPrank();

        bytes memory result = abi.encodeWithSelector(SkipCCTPDepositAccount.InsufficientBalanceForSkipGoFee.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
