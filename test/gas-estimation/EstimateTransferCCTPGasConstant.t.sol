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

import {TransferCCTPAction} from "../../src/actions/TransferCCTPAction.sol";
import {ITransferCCTPAction} from "../../src/actions/interfaces/ITransferCCTPAction.sol";

contract EstimateTransferCCTPGasConstant is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    Treasury treasury;
    FeeTokenRegistry feeTokenRegistry;

    TransferCCTPAction transferCCTPAction;

    VmSafe.Wallet public target = vm.createWallet("target");

    address public constant SEPOLIA_TOKEN_MINTER = address(0xE997d7d2F6E065a9A93Fa2175E878Fb9081F1f0A);
    address public constant SEPOLIA_TOKEN_MESSENGER = address(0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5);

    address public constant SEPOLIA_WETH9 = address(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);

    address public constant SEPOLIA_USDC = address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
    address public constant SEPOLIA_USDC_WHALE = address(0x1fD9611f009fcB8Bec0A4854FDcA0832DfdB04E3);

    uint256 public constant TRANSFER_CCTP_ACTION_GAS_CONSTANT = 105_500;

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
        transferCCTPAction = new TransferCCTPAction(
            SEPOLIA_TOKEN_MESSENGER,
            SEPOLIA_TOKEN_MINTER,
            address(feeTokenRegistry),
            address(treasury),
            TRANSFER_CCTP_ACTION_GAS_CONSTANT
        );

        actionManager.addAction(address(transferCCTPAction));
    }

    // check that the TRANSFER_CCTP_ACTION_GAS_CONSTANT doesn't result in an underpayment of the fee
    function testFuzz_transferCCTP_gasConstant(
        uint256 salt,
        uint256 maxExecutions,
        ITransferCCTPAction.TransferCCTP memory arguments
    ) public {
        arguments.token = SEPOLIA_USDC;

        arguments.destinationDomain = 4;
        arguments.destinationMintRecipient = bytes32(uint256(1));

        // assume a reasonable amount
        vm.assume(arguments.amount > 0 && arguments.amount < IERC20(SEPOLIA_USDC).balanceOf(SEPOLIA_USDC_WHALE));

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

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), arguments.amount);
        vm.stopPrank();

        // build Instruction with fuzz values
        buildInstruction(salt, maxExecutions, address(transferCCTPAction), abi.encode(arguments));

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
