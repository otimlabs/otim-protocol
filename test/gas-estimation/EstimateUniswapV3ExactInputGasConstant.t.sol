// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/src/Test.sol";
import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "@chainlink-contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";
import {IWETH9} from "../../src/actions/external/IWETH9.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {InstructionForkTestContext} from "../utils/InstructionForkTestContext.sol";

import {FeeTokenRegistry} from "../../src/infrastructure/FeeTokenRegistry.sol";
import {Treasury} from "../../src/infrastructure/Treasury.sol";

import {IInterval} from "../../src/actions/schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {UniswapV3ExactInputAction} from "../../src/actions/UniswapV3ExactInputAction.sol";
import {IUniswapV3ExactInputAction} from "../../src/actions/interfaces/IUniswapV3ExactInputAction.sol";

contract EstimateUniswapV3ExactInputConstant is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    Treasury treasury;
    FeeTokenRegistry feeTokenRegistry;

    UniswapV3ExactInputAction swapAction;

    VmSafe.Wallet public target = vm.createWallet("target");

    address public constant SEPOLIA_UNIVERSAL_ROUTER = address(0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD);
    address public constant SEPOLIA_V3_FACTORY = address(0x0227628f3F023bb0B980b67D528571c95c6DaC1c);
    address public constant SEPOLIA_WETH9 = address(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);

    address public constant SEPOLIA_USDC = address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);

    uint256 public constant UNISWAP_V3_EXACT_INPUT_GAS_CONSTANT = 107_000;

    constructor() {
        string memory rpcUrl = vm.envOr("SEPOLIA_RPC_URL", string("https://ethereum-sepolia-rpc.publicnode.com"));

        vm.createSelectFork(rpcUrl);

        treasury = new Treasury(address(this));
        feeTokenRegistry = new FeeTokenRegistry(address(this));

        // create mock price feed for WETH9 (always 1:1 with ETH)
        MockV3Aggregator priceFeed = new MockV3Aggregator(18, 1e18);

        // add WETH9 and mock price feed to fee token registry
        feeTokenRegistry.addFeeToken(SEPOLIA_WETH9, address(priceFeed), type(uint40).max);

        // deploy and whitelist action with new gas constant
        swapAction = new UniswapV3ExactInputAction(
            SEPOLIA_UNIVERSAL_ROUTER,
            SEPOLIA_V3_FACTORY,
            SEPOLIA_WETH9,
            address(feeTokenRegistry),
            address(treasury),
            UNISWAP_V3_EXACT_INPUT_GAS_CONSTANT
        );

        actionManager.addAction(address(swapAction));
    }

    // check that the UNISWAP_V3_EXACT_INPUT_GAS_CONSTANT doesn't result in an underpayment of the fee
    function testFuzz_uniswapV3ExactInput_gasConstant(
        uint256 salt,
        uint256 maxExecutions,
        IUniswapV3ExactInputAction.UniswapV3ExactInput memory arguments
    ) public {
        vm.pauseGasMetering();

        // fuzz test must pass argument validation
        vm.assume(arguments.recipient != address(0));

        // disregard fuzz generated values
        arguments.tokenIn = address(0);
        arguments.tokenOut = SEPOLIA_USDC;
        arguments.feeTier = 500;

        // assume a reasonable amountIn
        vm.assume(arguments.amountIn > 0 && arguments.amountIn < 100 ether);
        // disregard fuzz generated minAmountOut
        arguments.floorAmountOut = 0;

        // set look back period to 30 minutes
        arguments.meanPriceLookBack = 1800;

        // set maxPriceDeviationBPS to 100% (10_000 BPS) for simplicity
        arguments.maxPriceDeviationBPS = 10000;

        // fuzz test must pass schedule checks
        vm.assume(arguments.schedule.startAt < block.timestamp && arguments.schedule.startBy > block.timestamp);
        // assume interval and timeout are not ridiculously high
        vm.assume(arguments.schedule.interval < type(uint40).max && arguments.schedule.timeout < type(uint40).max);

        // disregard fuzz generated fee token
        arguments.fee.token = SEPOLIA_WETH9;
        // assume maxBaseFeePerGas and maxPriorityFeePerGas are non-zero and not ridiculously high
        vm.assume(arguments.fee.maxBaseFeePerGas > 0 && arguments.fee.maxBaseFeePerGas < type(uint64).max);
        vm.assume(arguments.fee.maxPriorityFeePerGas > 0 && arguments.fee.maxPriorityFeePerGas < type(uint64).max);
        // assume tx.gasprice is not ridiculously high
        vm.assume(arguments.fee.maxBaseFeePerGas + arguments.fee.maxPriorityFeePerGas < type(uint64).max);
        // assume executionFee is non-zero (to enable fee calculation) and not ridiculously high
        vm.assume(arguments.fee.executionFee > 0 && arguments.fee.executionFee < 100 ether);

        // set block.base fee and transaction priority fee based on fuzz values
        vm.fee(arguments.fee.maxBaseFeePerGas);
        vm.txGasPrice(arguments.fee.maxBaseFeePerGas + arguments.fee.maxPriorityFeePerGas);

        // deal enough fee balance and convert to WETH
        vm.deal(address(user), type(uint248).max - 1);
        vm.prank(address(user));
        IWETH9(SEPOLIA_WETH9).deposit{value: address(user).balance}();

        // deal enough ETH to swap based on fuzzed values
        vm.deal(address(user), arguments.amountIn);

        // build Instruction with fuzz values
        buildInstruction(salt, maxExecutions, address(swapAction), abi.encode(arguments));

        // execute and measure gas used
        vm.resumeGasMetering();
        uint256 gasUsed = gasleft();
        gateway.safeExecuteInstruction(address(user), instruction, instructionSig);
        gasUsed -= gasleft();
        vm.pauseGasMetering();

        uint256 feeCollected = IERC20(SEPOLIA_WETH9).balanceOf(address(treasury));
        uint256 executionCost = gasUsed * tx.gasprice;

        // revert if fee collected is less than transaction cost + executor tip
        assertGe(feeCollected, executionCost + arguments.fee.executionFee);
    }
}
