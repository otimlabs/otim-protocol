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

import {CallOnceAction} from "../../src/actions/CallOnceAction.sol";
import {ICallOnceAction} from "../../src/actions/interfaces/ICallOnceAction.sol";

contract EstimateCallOnceGasConstant is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    Treasury treasury;
    FeeTokenRegistry feeTokenRegistry;

    CallOnceAction callOnceAction;

    VmSafe.Wallet public target = vm.createWallet("target");

    uint256 public constant CALL_ONCE_GAS_CONSTANT = 109_000;

    constructor() {
        setUpFork();

        treasury = new Treasury(address(this));
        feeTokenRegistry = new FeeTokenRegistry(address(this));

        // create mock price feed for WETH9 (always 1:1 with ETH)
        MockV3Aggregator priceFeed = new MockV3Aggregator(18, 1e18);

        // add WETH9 and mock price feed to fee token registry
        feeTokenRegistry.addFeeToken(SEPOLIA_WETH9, address(priceFeed), type(uint40).max);

        // deploy and whitelist action with new gas constant
        callOnceAction = new CallOnceAction(
            address(instructionStorage), address(feeTokenRegistry), address(treasury), CALL_ONCE_GAS_CONSTANT
        );

        actionManager.addAction(address(callOnceAction));
    }

    // check that the CALL_ONCE_GAS_CONSTANT doesn't result in an underpayment of the fee
    function testFuzz_callOnce_gasConstant(uint256 salt, ICallOnceAction.CallOnce memory arguments) public {
        // always allow failure so the fuzzer can't force a failure
        arguments.allowFailure = true;

        // assume target is valid
        vm.assume(arguments.target != address(0) && arguments.target != address(instructionStorage));

        // assume value is not ridiculously high
        vm.assume(arguments.value < 100 ether);

        // assume gasLimit is not ridiculously high
        vm.assume(arguments.gasLimit < 30_000_000);

        // assume data length is not very high
        vm.assume(arguments.data.length < 450);

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

        vm.deal(address(user), arguments.value);

        // build Instruction with fuzz values (maxExecutions is set to 1)
        buildInstruction(salt, 1, address(callOnceAction), abi.encode(arguments));

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
