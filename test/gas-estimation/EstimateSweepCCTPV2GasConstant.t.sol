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

import {SweepCCTPV2Action} from "../../src/actions/SweepCCTPV2Action.sol";
import {ISweepCCTPV2Action} from "../../src/actions/interfaces/ISweepCCTPV2Action.sol";

contract EstimateSweepCCTPV2GasConstant is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    Treasury treasury;
    FeeTokenRegistry feeTokenRegistry;

    SweepCCTPV2Action sweepCCTPV2Action;

    VmSafe.Wallet public target = vm.createWallet("target");

    uint256 public constant SWEEP_CCTP_V2_ACTION_GAS_CONSTANT = 106_000;

    constructor() {
        setUpFork();

        treasury = new Treasury(address(this));
        feeTokenRegistry = new FeeTokenRegistry(address(this));

        // create mock price feed for WETH9 (always 1:1 with ETH)
        MockV3Aggregator priceFeed = new MockV3Aggregator(18, 1e18);

        // add WETH9 and mock price feed to fee token registry
        feeTokenRegistry.addFeeToken(SEPOLIA_WETH9, address(priceFeed), type(uint40).max);

        // deploy and whitelist action with new gas constant
        sweepCCTPV2Action = new SweepCCTPV2Action(
            SEPOLIA_TOKEN_MESSENGER_V2,
            SEPOLIA_TOKEN_MINTER_V2,
            address(feeTokenRegistry),
            address(treasury),
            SWEEP_CCTP_V2_ACTION_GAS_CONSTANT
        );

        actionManager.addAction(address(sweepCCTPV2Action));
    }

    // check that the SWEEP_CCTP_V2_ACTION_GAS_CONSTANT doesn't result in an underpayment of the fee
    function testFuzz_sweepCCTPV2_gasConstant(
        uint256 salt,
        uint256 maxExecutions,
        uint256 threshold,
        uint256 endBalance,
        uint256 maxBaseFeePerGas,
        uint256 maxPriorityFeePerGas,
        uint256 executionFee
    ) public {
        ISweepCCTPV2Action.SweepCCTPV2 memory arguments;

        arguments.token = SEPOLIA_USDC;
        arguments.destinationDomain = 2; // OP Sepolia
        arguments.destinationMintRecipient = bytes32(uint256(1));
        arguments.destinationCaller = bytes32(0);
        arguments.maxFee = 1e6;
        arguments.transferSpeed = ISweepCCTPV2Action.TransferSpeed.FAST;
        arguments.threshold = threshold;
        arguments.endBalance = endBalance;
        // fuzz test must pass argument validation
        vm.assume(endBalance <= threshold);
        // assume threshold is greater than maxFee for CCTP V2 validation
        vm.assume(threshold > arguments.maxFee);
        // assume a reasonable threshold (less than whale balance)
        vm.assume(threshold < IERC20(SEPOLIA_USDC).balanceOf(SEPOLIA_USDC_WHALE));
        // assume threshold is at least 2 USDC to have meaningful transfer amounts
        vm.assume(threshold >= 2e6);

        // set fee parameters with fuzzed values
        arguments.fee.token = SEPOLIA_WETH9;
        // assume maxBaseFeePerGas and maxPriorityFeePerGas are non-zero and not ridiculously high
        vm.assume(maxBaseFeePerGas > 0 && maxBaseFeePerGas < type(uint64).max);
        vm.assume(maxPriorityFeePerGas > 0 && maxPriorityFeePerGas < type(uint64).max);
        // assume tx.gasprice is not ridiculously high
        vm.assume(maxBaseFeePerGas + maxPriorityFeePerGas < type(uint64).max);
        // assume executionFee is non-zero (to enable fee calculation) and not ridiculously high
        vm.assume(executionFee > 0 && executionFee < 100 ether);

        arguments.fee.maxBaseFeePerGas = maxBaseFeePerGas;
        arguments.fee.maxPriorityFeePerGas = maxPriorityFeePerGas;
        arguments.fee.executionFee = executionFee;

        // set block.base fee and transaction priority fee based on fuzz values
        vm.fee(arguments.fee.maxBaseFeePerGas);
        vm.txGasPrice(arguments.fee.maxBaseFeePerGas + arguments.fee.maxPriorityFeePerGas);

        // deal enough fee balance and convert to WETH
        vm.deal(address(user), type(uint248).max - 1);
        vm.prank(address(user));
        IWETH9(SEPOLIA_WETH9).deposit{value: address(user).balance}();

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), arguments.threshold + 1);
        vm.stopPrank();

        // build Instruction with fuzz values
        buildInstruction(salt, maxExecutions, address(sweepCCTPV2Action), abi.encode(arguments));

        // execute and measure gas used
        uint256 gasUsed = gasleft();
        gateway.safeExecuteInstruction(address(user), instruction, instructionSig);
        gasUsed -= gasleft();

        uint256 feeCollected = IERC20(SEPOLIA_WETH9).balanceOf(address(treasury));
        uint256 executionCost = gasUsed * tx.gasprice;

        // revert if fee collected is less than transaction cost + executor tip
        assertGe(feeCollected, executionCost + arguments.fee.executionFee);

        vm.resetGasMetering();
    }
}

