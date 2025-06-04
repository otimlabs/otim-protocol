// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

import {IWETH9} from "../../src/actions/external/IWETH9.sol";

import {InstructionForkTestContext} from "../utils/InstructionForkTestContext.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

import {IInterval} from "../../src/actions/schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {IUniswapV3ExactInputAction} from "../../src/actions/interfaces/IUniswapV3ExactInputAction.sol";
import {UniswapV3ExactInputAction} from "../../src/actions/UniswapV3ExactInputAction.sol";

import "../../src/actions/errors/Errors.sol";

contract UniswapV3ExactInputTest is InstructionForkTestContext {
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
    uint256 DEFAULT_AMOUNT_IN = 1 ether;
    uint256 DEFAULT_FLOOR_AMOUNT_OUT = 1;
    uint32 DEFAULT_MEAN_PRICE_LOOKBACK = 3600; // 1 hour in seconds
    uint32 DEFAULT_MAX_PRICE_DEVIATION_BPS = 500; // 5%

    uint256 DEFAULT_START_AT;
    uint256 DEFAULT_START_BY;
    uint256 DEFAULT_INTERVAL;
    uint256 DEFAULT_TIMEOUT;
    IInterval.Schedule public DEFAULT_SCHEDULE;

    IOtimFee.Fee public DEFAULT_FEE;

    IUniswapV3ExactInputAction.UniswapV3ExactInput public DEFAULT_ACTION_ARGS;

    /// @dev from Uniswap V3SwapRouter
    error V3TooLittleReceived();

    constructor() {
        string memory rpcUrl = vm.envOr("SEPOLIA_RPC_URL", string("https://ethereum-sepolia-rpc.publicnode.com"));

        vm.createSelectFork(rpcUrl);

        UniswapV3ExactInputAction swapAction = new UniswapV3ExactInputAction(
            SEPOLIA_UNIVERSAL_ROUTER, SEPOLIA_V3_FACTORY, SEPOLIA_WETH9, address(0), address(0), 0
        );

        /// @notice Action setup
        actionManager.addAction(address(swapAction));

        /// @notice Schedule defaults
        DEFAULT_START_AT = block.timestamp - 1;
        DEFAULT_START_BY = block.timestamp + 10000;
        DEFAULT_INTERVAL = 36000;
        DEFAULT_TIMEOUT = 36000;
        DEFAULT_SCHEDULE = IInterval.Schedule({
            startAt: DEFAULT_START_AT,
            startBy: DEFAULT_START_BY,
            interval: DEFAULT_INTERVAL,
            timeout: DEFAULT_TIMEOUT
        });

        DEFAULT_ACTION_ARGS = IUniswapV3ExactInputAction.UniswapV3ExactInput({
            tokenIn: DEFAULT_TOKEN_IN,
            tokenOut: DEFAULT_TOKEN_OUT,
            feeTier: DEFAULT_FEE_TIER,
            recipient: DEFAULT_RECIPIENT,
            amountIn: DEFAULT_AMOUNT_IN,
            floorAmountOut: DEFAULT_FLOOR_AMOUNT_OUT,
            meanPriceLookBack: DEFAULT_MEAN_PRICE_LOOKBACK,
            maxPriceDeviationBPS: DEFAULT_MAX_PRICE_DEVIATION_BPS,
            schedule: DEFAULT_SCHEDULE,
            fee: DEFAULT_FEE
        });

        /// @notice Instruction defaults
        DEFAULT_ACTION = address(swapAction);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice test that swapping ETH to ERC20 works as expected
    function test_uniswapV3ExactInput_ethToToken() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertGt(IERC20(DEFAULT_TOKEN_OUT).balanceOf(DEFAULT_RECIPIENT), DEFAULT_FLOOR_AMOUNT_OUT);
    }

    /// @notice test that swapping ERC20 to ERC20 works as expected
    function test_uniswapV3ExactInput_tokenToToken() public {
        vm.pauseGasMetering();

        vm.prank(address(user));
        IWETH9(SEPOLIA_WETH9).deposit{value: DEFAULT_AMOUNT_IN}();

        DEFAULT_ACTION_ARGS.tokenIn = SEPOLIA_WETH9;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertGt(IERC20(DEFAULT_TOKEN_OUT).balanceOf(DEFAULT_RECIPIENT), DEFAULT_FLOOR_AMOUNT_OUT);
    }

    /// @notice test that swapping ERC20 to ETH works as expected
    function test_uniswapV3ExactInput_tokenToEth() public {
        vm.pauseGasMetering();

        vm.startPrank(SEPOLIA_USDC_WHALE);
        IERC20(SEPOLIA_USDC).transfer(address(user), IERC20(SEPOLIA_USDC).balanceOf(SEPOLIA_USDC_WHALE));
        vm.stopPrank();

        DEFAULT_ACTION_ARGS.tokenIn = SEPOLIA_USDC;
        DEFAULT_ACTION_ARGS.amountIn = 100e6; // 100 USDC
        DEFAULT_ACTION_ARGS.tokenOut = address(0);

        vm.deal(address(user), 0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        assertGt(address(user).balance, DEFAULT_FLOOR_AMOUNT_OUT);
    }

    /// @notice test that the user can't swap the same token
    function test_uniswapV3ExactInput_sameToken() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.tokenIn = SEPOLIA_USDC;
        DEFAULT_ACTION_ARGS.tokenOut = SEPOLIA_USDC;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the user can't set the recipient to address(0)
    function test_uniswapV3ExactInput_recipientZero() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.recipient = address(0);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the user can't set the swap amount to 0
    function test_uniswapV3ExactInput_amountInZero() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.amountIn = 0;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InvalidArguments.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that ETH to ERC20 swapping reverts if the user has insufficient ETH
    function test_uniswapV3ExactInput_insufficientEthBalance() public {
        vm.pauseGasMetering();

        vm.deal(address(user), 0);

        buildInstruction();

        bytes memory result = abi.encodeWithSelector(InsufficientBalance.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that ERC20 to ERC20 swapping reverts if the user has insufficient token balance
    function test_uniswapV3ExactInput_insufficientTokenBalance() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.tokenIn = SEPOLIA_USDC;
        DEFAULT_ACTION_ARGS.tokenOut = SEPOLIA_WETH9;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(InsufficientBalance.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the swap reverts if the user receives less than the minimum amount out
    function test_uniswapV3ExactInput_receivedTooLittle() public {
        vm.pauseGasMetering();

        DEFAULT_ACTION_ARGS.floorAmountOut = type(uint256).max;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(V3TooLittleReceived.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the swap reverts if the UniswapV3 pool doesn't exist
    function test_uniswapV3ExactInput_nonExistentPool() public {
        vm.pauseGasMetering();

        // not a valid fee tier
        DEFAULT_ACTION_ARGS.feeTier = 501;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(UniswapV3PoolDoesNotExist.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that the swap reverts if the current UniswapV3 pool price has deviated too much from the mean price
    function test_uniswapV3ExactInput_priceDeviationTooHigh() public {
        vm.pauseGasMetering();

        // set the lowest possible max price deviation
        DEFAULT_ACTION_ARGS.maxPriceDeviationBPS = 1;

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(DEFAULT_ACTION_ARGS));

        bytes memory result = abi.encodeWithSelector(V3TooLittleReceived.selector);
        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, result));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }
}
