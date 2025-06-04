// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IInterval} from "../schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,UniswapV3ExactInput uniswapV3ExactInput)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)UniswapV3ExactInput(address recipient,address tokenIn,address tokenOut,uint24 feeTier,uint256 amountIn,uint256 floorAmountOut,uint32 meanPriceLookBack,uint32 maxPriceDeviationBPS,Schedule schedule,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "UniswapV3ExactInput(address recipient,address tokenIn,address tokenOut,uint24 feeTier,uint256 amountIn,uint256 floorAmountOut,uint32 meanPriceLookBack,uint32 maxPriceDeviationBPS,Schedule schedule,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)"
);

/// @title IUniswapV3ExactInputAction
/// @author Otim Labs, Inc.
/// @notice interface for UniswapV3ExactInputAction contract
interface IUniswapV3ExactInputAction is IInterval, IOtimFee {
    /// @notice arguments for the UniswapV3ExactInputAction contract
    /// @param recipient - the address to send tokenOut to
    /// @param tokenIn - the address of the input token
    /// @param tokenOut - the address of the output token
    /// @param feeTier - the fee tier for the Uniswap V3 pool
    /// @param amountIn - the amount of tokenIn to swap
    /// @param floorAmountOut - the absolute minimum amount of tokenOut to receive each time the swap is executed
    /// @param meanPriceLookBack - the number of seconds to look back for calculating the mean price
    /// @param maxPriceDeviationBPS - the maximum price deviation in basis points
    /// @param schedule - the schedule parameters for the swap
    /// @param fee - the fee Otim will charge for the swap
    struct UniswapV3ExactInput {
        address recipient;
        address tokenIn;
        address tokenOut;
        uint24 feeTier;
        uint256 amountIn;
        uint256 floorAmountOut;
        uint32 meanPriceLookBack;
        uint32 maxPriceDeviationBPS;
        Schedule schedule;
        Fee fee;
    }

    /// @notice calculates the EIP-712 hash of the UniswapV3ExactInput struct
    function hash(UniswapV3ExactInput memory uniswapV3ExactInput) external pure returns (bytes32);
}
