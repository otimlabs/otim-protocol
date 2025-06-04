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

import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {RefuelERC20Action} from "../../src/actions/RefuelERC20Action.sol";
import {IRefuelERC20Action} from "../../src/actions/interfaces/IRefuelERC20Action.sol";

contract EstimateRefuelERC20GasConstant is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    Treasury treasury;
    FeeTokenRegistry feeTokenRegistry;

    RefuelERC20Action refuelERC20Action;

    VmSafe.Wallet public target = vm.createWallet("target");

    address public constant SEPOLIA_WETH9 = address(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);

    uint256 public constant REFUEL_ERC20_GAS_CONSTANT = 104_500;

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
        refuelERC20Action =
            new RefuelERC20Action(address(feeTokenRegistry), address(treasury), REFUEL_ERC20_GAS_CONSTANT);

        actionManager.addAction(address(refuelERC20Action));
    }

    // check that the REFUEL_ERC20_GAS_CONSTANT doesn't result in an underpayment of the fee
    function testFuzz_refuelERC20_gasConstant(
        uint256 salt,
        uint256 maxExecutions,
        IRefuelERC20Action.RefuelERC20 memory arguments
    ) public {
        vm.pauseGasMetering();

        // disregard fuzz generated token
        arguments.token = SEPOLIA_WETH9;
        // disregard fuzz generated target
        arguments.target = payable(target.addr);
        // fuzz test must pass argument validation
        vm.assume(arguments.threshold < arguments.endBalance);
        // assume a reasonable endBalance
        vm.assume(arguments.endBalance < 100 ether);

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

        // build Instruction with fuzz values
        buildInstruction(salt, maxExecutions, address(refuelERC20Action), abi.encode(arguments));

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
