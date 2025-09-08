// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,SweepUniswapV3 sweepUniswapV3)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)SweepUniswapV3(address recipient,address tokenIn,address tokenOut,uint24 feeTier,uint256 threshold,uint256 endBalance,uint256 floorAmountOut,uint32 meanPriceLookBack,uint32 maxPriceDeviationBPS,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "SweepUniswapV3(address recipient,address tokenIn,address tokenOut,uint24 feeTier,uint256 threshold,uint256 endBalance,uint256 floorAmountOut,uint32 meanPriceLookBack,uint32 maxPriceDeviationBPS,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title ISweepUniswapV3Action
/// @author Otim Labs, Inc.
/// @notice interface for SweepUniswapV3Action contract
interface ISweepUniswapV3Action is IOtimFee {
    /// @notice arguments for the SweepUniswapV3Action contract
    /// @param recipient - the address to send tokenOut to
    /// @param tokenIn - the address of the input token
    /// @param tokenOut - the address of the output token
    /// @param feeTier - the fee tier for the Uniswap V3 pool
    /// @param threshold - the tokenIn balance threshold to trigger the swap
    /// @param endBalance - the tokenIn balance after the swap
    /// @param floorAmountOut - the absolute minimum amount of tokenOut to receive each time the swap is executed
    /// @param meanPriceLookBack - the number of seconds to look back for calculating the mean price
    /// @param maxPriceDeviationBPS - the maximum price deviation in basis points
    /// @param fee - the fee Otim will charge for the swap
    struct SweepUniswapV3 {
        address recipient;
        address tokenIn;
        address tokenOut;
        uint24 feeTier;
        uint256 threshold;
        uint256 endBalance;
        uint256 floorAmountOut;
        uint32 meanPriceLookBack;
        uint32 maxPriceDeviationBPS;
        Fee fee;
    }

    /// @notice calculates the EIP-712 hash of the SweepUniswapV3 struct
    function hash(SweepUniswapV3 memory arguments) external pure returns (bytes32);
}
