// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

import {IWETH9} from "../../src/actions/external/IWETH9.sol";

import {InstructionForkTestContext} from "../utils/InstructionForkTestContext.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {ISweepUniswapV3Action} from "../../src/actions/interfaces/ISweepUniswapV3Action.sol";
import {SweepUniswapV3Action} from "../../src/actions/SweepUniswapV3Action.sol";

import "../../src/actions/errors/Errors.sol";

contract SweepUniswapV3Test is InstructionForkTestContext {
    using InstructionLib for InstructionLib.Instruction;

    address public constant SEPOLIA_UNIVERSAL_ROUTER = address(0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD);
    address public constant SEPOLIA_V3_FACTORY = address(0x0227628f3F023bb0B980b67D528571c95c6DaC1c);
    address public constant SEPOLIA_WETH9 = address(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);

    address public constant SEPOLIA_USDC = address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);

    address public constant SEPOLIA_USDC_WHALE = address(0x1fD9611f009fcB8Bec0A4854FDcA0832DfdB04E3);

    address DEFAULT_TOKEN_IN = address(0);
    address DEFAULT_TOKEN_OUT = SEPOLIA_USDC;
    uint24 DEFAULT_FEE_TIER = 500;
    address DEFAULT_RECIPIENT = address(user);
    uint256 DEFAULT_THRESHOLD = 2 gwei;
    uint256 DEFAULT_END_BALANCE = 1 gwei;
    uint256 DEFAULT_FLOOR_AMOUNT_OUT = 1;
    uint32 DEFAULT_MEAN_PRICE_LOOKBACK = 3600; // 1 hour in seconds
    uint32 DEFAULT_MAX_PRICE_DEVIATION_BPS = 500; // 5%

    IOtimFee.Fee public DEFAULT_FEE;

    ISweepUniswapV3Action.SweepUniswapV3 public DEFAULT_ACTION_ARGS;

    /// @dev from Uniswap V3SwapRouter
    error V3TooLittleReceived();

    constructor() {
        string memory rpcUrl = vm.envOr("SEPOLIA_RPC_URL", string("https://ethereum-sepolia-rpc.publicnode.com"));

        vm.createSelectFork(rpcUrl);

        SweepUniswapV3Action sweepUniswapV3Action = new SweepUniswapV3Action(
            SEPOLIA_UNIVERSAL_ROUTER, SEPOLIA_V3_FACTORY, SEPOLIA_WETH9, address(0), address(0), 0
        );

        /// @notice Action setup
        actionManager.addAction(address(sweepUniswapV3Action));

        DEFAULT_ACTION_ARGS = ISweepUniswapV3Action.SweepUniswapV3({
            recipient: DEFAULT_RECIPIENT,
            tokenIn: DEFAULT_TOKEN_IN,
            tokenOut: DEFAULT_TOKEN_OUT,
            feeTier: DEFAULT_FEE_TIER,
            threshold: DEFAULT_THRESHOLD,
            endBalance: DEFAULT_END_BALANCE,
            floorAmountOut: DEFAULT_FLOOR_AMOUNT_OUT,
            meanPriceLookBack: DEFAULT_MEAN_PRICE_LOOKBACK,
            maxPriceDeviationBPS: DEFAULT_MAX_PRICE_DEVIATION_BPS,
            fee: DEFAULT_FEE
        });

        /// @notice Instruction defaults
        DEFAULT_ACTION = address(sweepUniswapV3Action);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice test that swapping ETH to ERC20 works as expected
    function test_sweepUniswapV3_ethToToken() public {
        vm.pauseGasMetering();

        assertEq(address(user).balance, USER_START_BALANCE);

        buildInstruction();

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        user.executeInstruction(instruction, instructionSig);

        assertEq(address(user).balance, DEFAULT_END_BALANCE);
        assertGt(IERC20(DEFAULT_TOKEN_OUT).balanceOf(DEFAULT_RECIPIENT), DEFAULT_FLOOR_AMOUNT_OUT);
    }

    /// @notice test that swapping ERC20 to ERC20 works as expected
    function test_sweepUniswapV3_tokenToToken() public {
        vm.pauseGasMetering();

        vm.prank(address(user));
        IWETH9(SEPOLIA_WETH9).deposit{value: USER_START_BALANCE}();

        DEFAULT_ACTION_ARGS.tokenIn = SEPOLIA_WETH9;

        assertEq(IERC20(SEPOLIA_WETH9).balanceOf(address(user)), USER_START_BALANCE);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        user.executeInstruction(instruction, instructionSig);

        assertEq(IERC20(SEPOLIA_WETH9).balanceOf(address(user)), DEFAULT_END_BALANCE);
        assertGt(IERC20(DEFAULT_TOKEN_OUT).balanceOf(DEFAULT_RECIPIENT), DEFAULT_FLOOR_AMOUNT_OUT);
    }

    /// @notice test that swapping ERC20 to ETH works as expected
    function test_sweepUniswapV3_tokenToEth() public {
        vm.pauseGasMetering();

        vm.deal(address(user), 0);

        uint256 whaleBalance = IERC20(SEPOLIA_USDC).balanceOf(SEPOLIA_USDC_WHALE);

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), whaleBalance);
        vm.stopPrank();

        assertEq(IERC20(SEPOLIA_USDC).balanceOf(address(user)), whaleBalance);
        assertEq(address(user).balance, 0);

        DEFAULT_ACTION_ARGS.tokenIn = SEPOLIA_USDC;
        DEFAULT_ACTION_ARGS.tokenOut = address(0);
        DEFAULT_ACTION_ARGS.threshold = 0;
        DEFAULT_ACTION_ARGS.endBalance = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        user.executeInstruction(instruction, instructionSig);

        assertEq(IERC20(SEPOLIA_USDC).balanceOf(address(user)), DEFAULT_END_BALANCE);
        assertGt(address(user).balance, DEFAULT_FLOOR_AMOUNT_OUT);
    }

    /// @notice test that the user can't swap the same token
    function test_sweepUniswapV3_sameToken() public {
        DEFAULT_ACTION_ARGS.tokenIn = SEPOLIA_USDC;
        DEFAULT_ACTION_ARGS.tokenOut = SEPOLIA_USDC;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the user can't set the recipient to address(0)
    function test_sweepUniswapV3_recipientZero() public {
        DEFAULT_ACTION_ARGS.recipient = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the user can't set the endBalance above the threshold
    function test_sweepUniswapV3_endBalanceAboveThreshold() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.endBalance = DEFAULT_THRESHOLD + 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resetGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the user can't set the meanPriceLookBack to 0
    function test_sweepUniswapV3_meanPriceLookBackZero() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.meanPriceLookBack = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        user.executeInstruction(instruction, instructionSig);
    }

    /// @notice test that the user can't set the maxPriceDeviationBPS to 0
    function test_sweepUniswapV3_maxPriceDeviationBPSZero() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.maxPriceDeviationBPS = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        user.executeInstruction(instruction, instructionSig);
    }

    /// @notice test that ETH to ERC20 swapping reverts if the user has insufficient ETH
    function test_sweepUniswapV3_balanceUnderThreshold() public {
        vm.pauseGasMetering();

        vm.deal(address(user), 0);

        buildInstruction();

        bytes memory result = abi.encodeWithSelector(BalanceUnderThreshold.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        user.executeInstruction(instruction, instructionSig);
    }

    /// @notice test that the swap reverts if the user receives less than the minimum amount out
    function test_sweepUniswapV3_receivedTooLittle() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.floorAmountOut = type(uint256).max;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(V3TooLittleReceived.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        user.executeInstruction(instruction, instructionSig);
    }

    /// @notice test that the swap reverts if the UniswapV3 pool doesn't exist
    function test_sweepUniswapV3_nonExistentPool() public {
        vm.pauseGasMetering();

        // not a valid fee tier
        DEFAULT_ACTION_ARGS.feeTier = 501;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(UniswapV3PoolDoesNotExist.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        user.executeInstruction(instruction, instructionSig);
    }
}
