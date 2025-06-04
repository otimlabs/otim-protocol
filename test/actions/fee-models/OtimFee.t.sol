// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {ERC20MockWithDecimals} from "../../mocks/ERC20MockWithDecimals.sol";
import {MockV3Aggregator} from "@chainlink-contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";

import {InstructionTestContext} from "../../utils/InstructionTestContext.sol";

import {InstructionLib} from "../../../src/libraries/Instruction.sol";

import {IOtimDelegate} from "../../../src/IOtimDelegate.sol";

import {IFeeTokenRegistry} from "../../../src/infrastructure/interfaces/IFeeTokenRegistry.sol";
import {FeeTokenRegistry} from "../../../src/infrastructure/FeeTokenRegistry.sol";

import {ITreasury} from "../../../src/infrastructure/interfaces/ITreasury.sol";
import {Treasury} from "../../../src/infrastructure/Treasury.sol";

import {IInterval} from "../../../src/actions/schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {ITransferAction} from "../../../src/actions/interfaces/ITransferAction.sol";
import {TransferAction} from "../../../src/actions/TransferAction.sol";

import "../../../src/actions/errors/Errors.sol";

contract OtimFeeTest is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

    ERC20MockWithDecimals public USDC = new ERC20MockWithDecimals(6);

    IFeeTokenRegistry public feeTokenRegistry = new FeeTokenRegistry(address(this));
    ITreasury public treasury = new Treasury(address(this));
    uint256 public GAS_CONSTANT = 3_000;

    TransferAction public transfer = new TransferAction(address(feeTokenRegistry), address(treasury), GAS_CONSTANT);

    /// @notice test Transfer target
    VmSafe.Wallet public target = vm.createWallet("target");

    address payable public DEFAULT_TARGET = payable(target.addr);
    uint256 public DEFAULT_VALUE = 100;
    uint256 public DEFAULT_GAS_LIMIT = 21_000;

    IInterval.Schedule public DEFAULT_SCHEDULE;

    address public DEFAULT_FEE_TOKEN = address(0);
    uint256 public DEFAULT_MAX_BASE_PER_GAS = 5 gwei;
    uint256 public DEFAULT_MAX_PRIORITY_PER_GAS = 0.1 gwei;
    uint256 public DEFAULT_EXECUTION_FEE = 0.1 gwei;
    IOtimFee.Fee public DEFAULT_FEE = IOtimFee.Fee({
        token: DEFAULT_FEE_TOKEN,
        maxBaseFeePerGas: DEFAULT_MAX_BASE_PER_GAS,
        maxPriorityFeePerGas: DEFAULT_MAX_PRIORITY_PER_GAS,
        executionFee: DEFAULT_EXECUTION_FEE
    });

    ITransferAction.Transfer public DEFAULT_ACTION_ARGS = ITransferAction.Transfer({
        target: DEFAULT_TARGET,
        value: DEFAULT_VALUE,
        gasLimit: DEFAULT_GAS_LIMIT,
        schedule: DEFAULT_SCHEDULE,
        fee: DEFAULT_FEE
    });

    constructor() {
        MockV3Aggregator usdcPriceFeed = new MockV3Aggregator(18, 0);
        usdcPriceFeed.updateAnswer(449751386928257);

        /// @notice add USDC to feeTokenRegistry
        feeTokenRegistry.addFeeToken(address(USDC), address(usdcPriceFeed), 1 days);

        /// @notice Action setup
        actionManager.addAction(address(transfer));

        /// @notice set up VM block.basefee and tx.gasprice
        vm.fee(DEFAULT_MAX_BASE_PER_GAS);
        vm.txGasPrice(DEFAULT_MAX_BASE_PER_GAS + DEFAULT_MAX_PRIORITY_PER_GAS);

        /// @notice Instruction defaults
        DEFAULT_ACTION = address(transfer);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice test that no fee is charged when fee.value = 0
    function test_chargeFee_noFee() public {
        vm.pauseGasMetering();

        // keep defaults but set fee.executionFee to 0
        DEFAULT_ACTION_ARGS.fee.executionFee = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        assertEq(address(user).balance, USER_START_BALANCE);
        assertEq(address(treasury).balance, 0);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user ether balance only decreased by the transfer value
        assertEq(address(user).balance, USER_START_BALANCE - DEFAULT_VALUE);

        // check that the treasury ether balance is still 0
        assertEq(address(treasury).balance, 0);
    }

    /// @notice test that fee routing with ETH works as expected
    function test_chargeFee_ether() public {
        vm.pauseGasMetering();

        buildInstruction();

        assertEq(address(user).balance, USER_START_BALANCE);
        assertEq(address(treasury).balance, 0);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user ether balance decreased by more than the transfer value + executionFee (because gas payment is included)
        assertLt(address(user).balance, USER_START_BALANCE - DEFAULT_VALUE - DEFAULT_EXECUTION_FEE);

        // check treasury ether balance is greater than the executionFee (because gas payment is included)
        assertGt(address(treasury).balance, DEFAULT_EXECUTION_FEE);
    }

    /// @notice test that fee routing with ERC20 token works as expected
    function test_chargeFee_erc20() public {
        vm.pauseGasMetering();

        // keep defaults but set fee.token to USDC
        DEFAULT_ACTION_ARGS.fee.token = address(USDC);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        USDC.mint(address(user), USER_START_BALANCE);

        assertEq(USDC.balanceOf(address(user)), USER_START_BALANCE);
        assertEq(USDC.balanceOf(address(treasury)), 0);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user ether balance only decreased by the transfer value
        assertEq(address(user).balance, USER_START_BALANCE - DEFAULT_VALUE);

        // check that user ERC20 balance is less than the executionFee (because gas payment is included)
        assertLt(USDC.balanceOf(address(user)), USER_START_BALANCE - DEFAULT_EXECUTION_FEE);

        // check treasury ERC20 balance is greater than the executionFee (because gas payment is included)
        assertGt(USDC.balanceOf(address(treasury)), DEFAULT_EXECUTION_FEE);
    }

    /// @notice test that block.basefee can be anything when fee.maxBaseFeePerGas = 0
    function test_chargeFee_ether_maxBaseFeePerGasZero(uint256 baseFeePerGas) public {
        vm.pauseGasMetering();

        // assume block.basefee is less than 1 ether
        vm.assume(baseFeePerGas < 1 ether);

        // give the user enough ether to pay the extreme fee
        USER_START_BALANCE = 1_000_000 ether;
        vm.deal(address(user), USER_START_BALANCE);

        vm.fee(baseFeePerGas);
        vm.txGasPrice(baseFeePerGas + DEFAULT_MAX_PRIORITY_PER_GAS);

        // keep defaults but set fee.maxBaseFeePerGas to 0
        DEFAULT_ACTION_ARGS.fee.maxBaseFeePerGas = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        assertEq(address(user).balance, USER_START_BALANCE);
        assertEq(address(treasury).balance, 0);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        // check that the user ether balance decreased by more than the transfer value + executionFee (because gas payment is included)
        assertLt(address(user).balance, USER_START_BALANCE - DEFAULT_VALUE - DEFAULT_EXECUTION_FEE);

        // check treasury ether balance is greater than the executionFee (because gas payment is included)
        assertGt(address(treasury).balance, DEFAULT_EXECUTION_FEE);
    }

    /// @notice test that execution reverts with block.basefee > fee.maxBaseFeePerGas
    function test_chargeFee_baseFeePerGasTooHigh() public {
        vm.pauseGasMetering();

        vm.fee(DEFAULT_MAX_BASE_PER_GAS + 1);

        buildInstruction();

        bytes memory result = abi.encodeWithSelector(IOtimFee.BaseFeePerGasTooHigh.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with priorityFee > fee.maxPriorityFeePerGas
    function test_chargeFee_priorityFeePerGasTooHigh() public {
        vm.pauseGasMetering();

        vm.fee(DEFAULT_MAX_BASE_PER_GAS);
        vm.txGasPrice(DEFAULT_MAX_BASE_PER_GAS + DEFAULT_MAX_PRIORITY_PER_GAS + 1);

        buildInstruction();

        bytes memory result = abi.encodeWithSelector(IOtimFee.PriorityFeePerGasTooHigh.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with insufficient ETH fee balance
    function test_chargeFee_insufficientFeeBalance_ether() public {
        vm.pauseGasMetering();

        buildInstruction();

        // only deal the transfer value + executionFee (not enough to cover gas payment)
        vm.deal(address(user), DEFAULT_VALUE + DEFAULT_EXECUTION_FEE);

        bytes memory result = abi.encodeWithSelector(IOtimFee.InsufficientFeeBalance.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts with insufficient ERC20 fee balance
    function test_chargeFee_insufficientFeeBalance_erc20() public {
        vm.pauseGasMetering();

        // keep defaults but set fee.token to USDC
        DEFAULT_ACTION_ARGS.fee.token = address(USDC);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.deal(address(user), DEFAULT_VALUE);

        // only mint the executionFee (not enough to cover gas payment)
        USDC.mint(address(user), DEFAULT_EXECUTION_FEE);

        bytes memory result = abi.encodeWithSelector(IOtimFee.InsufficientFeeBalance.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that execution reverts if the fee token is not registered
    function test_chargeFee_tokenNotRegistered() public {
        vm.pauseGasMetering();

        // keep defaults but set fee.token to address(1)
        DEFAULT_ACTION_ARGS.fee.token = address(1);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(IFeeTokenRegistry.FeeTokenNotRegistered.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
