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

import {ISweepCCTPDepositAccountAction} from "../../src/actions/interfaces/ISweepCCTPDepositAccountAction.sol";
import {SweepCCTPDepositAccountAction} from "../../src/actions/SweepCCTPDepositAccountAction.sol";

import {CCTPDepositAccount} from "../../src/actions/transient-contracts/CCTPDepositAccount.sol";

import "../../src/actions/errors/Errors.sol";

contract SweepCCTPDepositAccountTest is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    address public constant SEPOLIA_USDC = address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
    address public constant SEPOLIA_TOKEN_MINTER = address(0xE997d7d2F6E065a9A93Fa2175E878Fb9081F1f0A);
    address public constant SEPOLIA_CCTP_RELAYER = address(0x3cb7630cAdd5bC6Cba3Aa331feb9b3D018A74f83);

    address public constant SEPOLIA_USDC_WHALE = address(0x1fD9611f009fcB8Bec0A4854FDcA0832DfdB04E3);

    SkipGoFeeOracle public skipGoFeeOracle;
    SweepCCTPDepositAccountAction public sweepCCTPDepositAccountAction;

    VmSafe.Wallet public depositor = vm.createWallet("depositor");

    uint256 public constant DEFAULT_SKIP_GO_FEE = 2000;

    address public DEFAULT_DEPOSITOR = depositor.addr;
    uint256 public DEFAULT_THRESHOLD = DEFAULT_SKIP_GO_FEE * 5;

    address public DEFAULT_DEPOSIT_ACCOUNT;

    IOtimFee.Fee public DEFAULT_FEE;

    ISweepCCTPDepositAccountAction.SweepCCTPDepositAccount public DEFAULT_ACTION_ARGS;

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

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), IERC20(SEPOLIA_USDC).balanceOf(SEPOLIA_USDC_WHALE));
        vm.stopPrank();

        skipGoFeeOracle = new SkipGoFeeOracle(address(this));

        skipGoFeeOracle.setFee(4, DEFAULT_SKIP_GO_FEE);

        sweepCCTPDepositAccountAction = new SweepCCTPDepositAccountAction(
            SEPOLIA_USDC,
            SEPOLIA_CCTP_RELAYER,
            SEPOLIA_TOKEN_MINTER,
            address(skipGoFeeOracle),
            address(0),
            address(0),
            0
        );

        actionManager.addAction(address(sweepCCTPDepositAccountAction));

        DEFAULT_ACTION_ARGS = ISweepCCTPDepositAccountAction.SweepCCTPDepositAccount({
            depositor: DEFAULT_DEPOSITOR,
            destinationDomain: 4,
            destinationMintRecipient: bytes32(uint256(1)),
            threshold: DEFAULT_THRESHOLD,
            fee: DEFAULT_FEE
        });

        DEFAULT_DEPOSIT_ACCOUNT = sweepCCTPDepositAccountAction.calculateDepositAddress(
            address(user),
            DEFAULT_ACTION_ARGS.depositor,
            DEFAULT_ACTION_ARGS.destinationDomain,
            DEFAULT_ACTION_ARGS.destinationMintRecipient
        );

        DEFAULT_ACTION = address(sweepCCTPDepositAccountAction);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice test that sweeping USDC to the CCTP relayer works as expected
    function test_sweepCCTPDepositAccount_happyPath() public {
        vm.pauseGasMetering();

        buildInstruction();

        uint256 feeAmount = skipGoFeeOracle.getFee(DEFAULT_ACTION_ARGS.destinationDomain);

        vm.startPrank(address(user));
        IERC20(SEPOLIA_USDC).transfer(DEFAULT_DEPOSIT_ACCOUNT, DEFAULT_THRESHOLD + 1);
        vm.stopPrank();

        assertEq(IERC20(SEPOLIA_USDC).balanceOf(DEFAULT_DEPOSIT_ACCOUNT), DEFAULT_THRESHOLD + 1);

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

        // check that the SkipGo fee was paid correctly
        // don't check the nonce
        vm.expectEmit(false, true, false, false);
        emit ICCTPRelayer.PaymentForRelay(0, feeAmount);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the deposit account is empty after the sweep
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(DEFAULT_DEPOSIT_ACCOUNT), 0);
    }

    /// @notice test that sweeping USDC to the CCTP relayer works as expected even when the deposit account has more USDC than the burn limit
    function test_sweepCCTPDepositAccount_overBurnLimit() public {
        vm.pauseGasMetering();

        buildInstruction();

        uint256 maxBurnPerMessage = ITokenController(SEPOLIA_TOKEN_MINTER).burnLimitsPerMessage(SEPOLIA_USDC);

        uint256 feeAmount = skipGoFeeOracle.getFee(DEFAULT_ACTION_ARGS.destinationDomain);

        vm.startPrank(address(user));
        IERC20(SEPOLIA_USDC).transfer(DEFAULT_DEPOSIT_ACCOUNT, maxBurnPerMessage * 5);
        vm.stopPrank();

        assertEq(IERC20(SEPOLIA_USDC).balanceOf(DEFAULT_DEPOSIT_ACCOUNT), maxBurnPerMessage * 5);

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

        // check that the SkipGo fee was paid correctly
        // don't check the nonce
        vm.expectEmit(false, true, false, false);
        emit ICCTPRelayer.PaymentForRelay(0, feeAmount);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the deposit account was swept up to the max burn limit (minus the fee)
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(DEFAULT_DEPOSIT_ACCOUNT), maxBurnPerMessage * 4 - feeAmount);
    }

    /// @notice test that sweeping USDC to the CCTP relayer works as expected when the deposit account also has ETH balance
    function test_sweepCCTPDepositAccount_withEthBalance() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.startPrank(address(user));
        IERC20(SEPOLIA_USDC).transfer(DEFAULT_DEPOSIT_ACCOUNT, DEFAULT_THRESHOLD + 1);
        vm.stopPrank();

        assertEq(IERC20(SEPOLIA_USDC).balanceOf(DEFAULT_DEPOSIT_ACCOUNT), DEFAULT_THRESHOLD + 1);

        // deal some ETH to the deposit account
        vm.deal(DEFAULT_DEPOSIT_ACCOUNT, 100);
        assertEq(DEFAULT_DEPOSIT_ACCOUNT.balance, 100);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the deposit account has no ETH or USDC balance after the sweep
        assertEq(DEFAULT_DEPOSIT_ACCOUNT.balance, 0);
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(DEFAULT_DEPOSIT_ACCOUNT), 0);

        // check that the ETH balance was credited to the depositor
        assertEq(DEFAULT_DEPOSITOR.balance, 100);
    }

    /// @notice test that the Instruction succeeds even if the deposit account is perminently deployed and can't be self-destructed
    /// @dev this case will never happen if the Action is used as intended, but it is technically possible for the owner to permanently deploy the deposit account
    function test_sweepCCTPDepositAccount_alreadyDeployed() public {
        vm.pauseGasMetering();

        buildInstruction();

        // permanently deploy the deposit account
        vm.prank(address(user));
        CCTPDepositAccount cctpDepositAccount = new CCTPDepositAccount(
            SEPOLIA_USDC,
            SEPOLIA_CCTP_RELAYER,
            SEPOLIA_TOKEN_MINTER,
            address(skipGoFeeOracle),
            DEFAULT_ACTION_ARGS.depositor,
            DEFAULT_ACTION_ARGS.destinationDomain,
            DEFAULT_ACTION_ARGS.destinationMintRecipient
        );
        vm.etch(DEFAULT_DEPOSIT_ACCOUNT, address(cctpDepositAccount).code);

        vm.startPrank(address(user));
        IERC20(SEPOLIA_USDC).transfer(DEFAULT_DEPOSIT_ACCOUNT, DEFAULT_THRESHOLD + 1);
        vm.stopPrank();

        assertEq(IERC20(SEPOLIA_USDC).balanceOf(DEFAULT_DEPOSIT_ACCOUNT), DEFAULT_THRESHOLD + 1);

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the deposit account was swept
        assertEq(IERC20(SEPOLIA_USDC).balanceOf(DEFAULT_DEPOSIT_ACCOUNT), 0);
    }

    /// @notice test that the Instruction reverts when the depositor is set to the zero address
    function test_sweepCCTPDepositAccount_depositorZero() public {
        vm.pauseGasMetering();

        // set the depositor to the zero address
        DEFAULT_ACTION_ARGS.depositor = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction reverts when the destinationMintRecipient is set to the zero address
    function test_sweepCCTPDepositAccount_destinationMintRecipientZero() public {
        vm.pauseGasMetering();

        // set the destinationMintRecipient to the zero address
        DEFAULT_ACTION_ARGS.destinationMintRecipient = bytes32(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction reverts when the deposit account balance is below the threshold
    function test_sweepCCTPDepositAccount_balanceUnderThreshold() public {
        vm.pauseGasMetering();

        buildInstruction();

        // set the deposit account balance to below the threshold
        vm.startPrank(address(user));
        IERC20(SEPOLIA_USDC).transfer(DEFAULT_DEPOSIT_ACCOUNT, DEFAULT_THRESHOLD - 1);
        vm.stopPrank();

        bytes memory result = abi.encodeWithSelector(BalanceUnderThreshold.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the Instruction reverts when the deposit account balance is below the SkipGo fee amount
    function test_sweepCCTPDepositAccount_insufficientSkipGoFeeBalance() public {
        vm.pauseGasMetering();

        // set threshold to zero to avoid the balance under threshold check
        DEFAULT_ACTION_ARGS.threshold = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        uint256 feeAmount = skipGoFeeOracle.getFee(DEFAULT_ACTION_ARGS.destinationDomain);

        // set the deposit account balance to below the SkipGo fee amount
        vm.startPrank(address(user));
        IERC20(SEPOLIA_USDC).transfer(DEFAULT_DEPOSIT_ACCOUNT, feeAmount - 1);
        vm.stopPrank();

        bytes memory result = abi.encodeWithSelector(CCTPDepositAccount.InsufficientBalanceForSkipGoFee.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
