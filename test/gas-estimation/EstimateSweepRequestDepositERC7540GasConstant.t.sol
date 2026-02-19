// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {VmSafe} from "forge-std/src/Vm.sol";

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "@chainlink-contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";
import {IWETH9} from "../../src/actions/external/IWETH9.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {InstructionForkTestContext} from "../utils/InstructionForkTestContext.sol";

import {FeeTokenRegistry} from "../../src/infrastructure/FeeTokenRegistry.sol";
import {Treasury} from "../../src/infrastructure/Treasury.sol";

import {SweepRequestDepositERC7540Action} from "../../src/actions/SweepRequestDepositERC7540Action.sol";
import {ISweepRequestDepositERC7540Action} from "../../src/actions/interfaces/ISweepRequestDepositERC7540Action.sol";

import {ERC20MockWithDecimals} from "../mocks/ERC20MockWithDecimals.sol";
import {ERC4626Mock} from "../mocks/ERC4626Mock.sol";
import {ERC7540DepositMock} from "../mocks/ERC7540DepositMock.sol";

contract EstimateSweepRequestDepositERC7540GasConstant is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    Treasury treasury;
    FeeTokenRegistry feeTokenRegistry;

    SweepRequestDepositERC7540Action sweepRequestDepositERC7540Action;

    ERC20MockWithDecimals public mockUSDC;
    ERC4626Mock public underlyingVault;
    ERC7540DepositMock public mockVault;

    uint256 public constant SWEEP_REQUEST_DEPOSIT_ERC7540_GAS_CONSTANT = 105_000;
    uint256 public constant USER_MINT_AMOUNT = 100_000e6;

    constructor() {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", vm.rpcUrl("mainnet"));
        vm.createSelectFork(rpcUrl);

        treasury = new Treasury(address(this));
        feeTokenRegistry = new FeeTokenRegistry(address(this));

        MockV3Aggregator priceFeed = new MockV3Aggregator(18, 1e18);
        feeTokenRegistry.addFeeToken(MAINNET_WETH9, address(priceFeed), type(uint40).max);

        sweepRequestDepositERC7540Action = new SweepRequestDepositERC7540Action(
            address(feeTokenRegistry), address(treasury), SWEEP_REQUEST_DEPOSIT_ERC7540_GAS_CONSTANT
        );

        mockUSDC = new ERC20MockWithDecimals(6);
        underlyingVault = new ERC4626Mock(IERC20(mockUSDC));
        mockVault = new ERC7540DepositMock(IERC20(underlyingVault));

        mockUSDC.mint(address(user), USER_MINT_AMOUNT);
        vm.startPrank(address(user));
        mockUSDC.approve(address(underlyingVault), USER_MINT_AMOUNT);
        underlyingVault.deposit(USER_MINT_AMOUNT, address(user));
        vm.stopPrank();

        actionManager.addAction(address(sweepRequestDepositERC7540Action));
    }

    function testFuzz_sweepRequestDepositERC7540_gasConstant(
        uint256 salt,
        uint256 maxExecutions,
        ISweepRequestDepositERC7540Action.SweepRequestDepositERC7540 memory arguments
    ) public {
        arguments.vault = address(mockVault);
        arguments.controller = address(user);
        arguments.minTotalShares = 1;

        uint256 userBalance = IERC20(underlyingVault).balanceOf(address(user));
        vm.assume(arguments.threshold <= userBalance);
        vm.assume(arguments.endBalance <= arguments.threshold);

        uint256 sweepAmount = userBalance - arguments.endBalance;
        vm.assume(arguments.minDeposit <= sweepAmount);

        arguments.fee.token = MAINNET_WETH9;
        vm.assume(arguments.fee.maxBaseFeePerGas > 0 && arguments.fee.maxBaseFeePerGas < type(uint64).max);
        vm.assume(arguments.fee.maxPriorityFeePerGas > 0 && arguments.fee.maxPriorityFeePerGas < type(uint64).max);
        vm.assume(arguments.fee.maxBaseFeePerGas + arguments.fee.maxPriorityFeePerGas < type(uint64).max);
        vm.assume(arguments.fee.executionFee > 0 && arguments.fee.executionFee < 100 ether);

        vm.fee(arguments.fee.maxBaseFeePerGas);
        vm.txGasPrice(arguments.fee.maxBaseFeePerGas + arguments.fee.maxPriorityFeePerGas);

        vm.deal(address(user), type(uint248).max - 1);
        vm.prank(address(user));
        IWETH9(MAINNET_WETH9).deposit{value: address(user).balance}();

        buildInstruction(salt, maxExecutions, address(sweepRequestDepositERC7540Action), abi.encode(arguments));

        uint256 gasUsed = gasleft();
        gateway.safeExecuteInstruction(address(user), instruction, instructionSig);
        gasUsed -= gasleft();

        uint256 feeCollected = IERC20(MAINNET_WETH9).balanceOf(address(treasury));
        uint256 executionCost = gasUsed * tx.gasprice;

        assertGe(feeCollected, executionCost + arguments.fee.executionFee);

        vm.resetGasMetering();
    }
}
