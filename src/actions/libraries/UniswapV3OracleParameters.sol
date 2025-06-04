// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {TickMath} from "@uniswap-v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@uniswap-v3-core/contracts/libraries/FullMath.sol";

import {IUniswapV3Pool} from "@uniswap-v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/// @title UniswapV3OracleParameters
/// @author Otim Labs, Inc.
/// @notice a library for calculating reasonable Uniswap V3 swap parameters based on recent price data
library UniswapV3OracleParameters {
    /// @notice the number of basis points per unit
    uint256 public constant BPS_PER_UNIT = 10000;

    /// @notice the number of hundredth basis points per unit
    uint256 public constant HUNDREDTH_BPS_PER_UNIT = BPS_PER_UNIT * 100;

    /// @notice calculates a reasonable minAmountOut for a swap based on the recent mean price of the Uniswap V3 pool
    /// @param poolAddress - the address of the Uniswap V3 pool
    /// @param tokenIn - the address of the input token
    /// @param tokenOut - the address of the output token
    /// @param feeTier - the fee tier of the Uniswap V3 pool (in hundredth basis points)
    /// @param amountIn - the amount of tokenIn to swap
    /// @param meanPriceLookBack - the number of seconds to look back for calculating the mean price ratio
    /// @param maxPriceDeviationBPS - the maximum price deviation in basis points
    /// @return minAmountOut - the minimum amount of tokenOut to receive after the swap
    function getMinAmountOutWithTwapDeviation(
        address poolAddress,
        address tokenIn,
        address tokenOut,
        uint24 feeTier,
        uint256 amountIn,
        uint32 meanPriceLookBack,
        uint32 maxPriceDeviationBPS
    ) internal view returns (uint256 minAmountOut) {
        // get the mean sqrt ratio over the look back period
        uint256 meanSqrtRatioX96 = getMeanSqrtRatioX96(poolAddress, meanPriceLookBack);

        // square the mean sqrt ratio to get the mean ratio (in X192 format)
        uint256 meanRatioX192 = meanSqrtRatioX96 * meanSqrtRatioX96;

        // calculate the amountIn after the fee is deducted (feeTier is denominated in hundredth basis points)
        amountIn *= HUNDREDTH_BPS_PER_UNIT - feeTier;
        amountIn /= HUNDREDTH_BPS_PER_UNIT;

        // if zeroForOne, multiply amountIn by the mean ratio, otherwise divide amountIn by the mean ratio
        minAmountOut = tokenIn < tokenOut
            ? FullMath.mulDiv(amountIn, meanRatioX192, 1 << 192)
            : FullMath.mulDiv(amountIn, 1 << 192, meanRatioX192);

        // adjust the minAmountOut based on the user-defined maximum price deviation denominated in basis points
        minAmountOut *= BPS_PER_UNIT - maxPriceDeviationBPS;
        minAmountOut /= BPS_PER_UNIT;
    }

    /// @notice calculates the mean sqrt ratio X96 of a Uniswap V3 pool over a certain look back period
    /// @param poolAddress - the address of the Uniswap V3 pool
    /// @param meanPriceLookBack - the number of seconds to look back for calculating the mean price ratio
    /// @return meanSqrtRatioX96 - the mean sqrt ratio X96 of the Uniswap V3 pool over the look back period
    function getMeanSqrtRatioX96(address poolAddress, uint32 meanPriceLookBack)
        internal
        view
        returns (uint160 meanSqrtRatioX96)
    {
        // get cumulative tick data from the Uniswap V3 pool over the look back period
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = meanPriceLookBack;
        secondsAgos[1] = 0;
        // slither-disable-next-line unused-return
        (int56[] memory tickCumulatives,) = IUniswapV3Pool(poolAddress).observe(secondsAgos);

        // calculate mean tick over look back period
        int56 tickDelta = tickCumulatives[1] - tickCumulatives[0];
        int24 meanTick = int24(tickDelta / int32(meanPriceLookBack));

        /// @dev round down if the tickDelta is negative and not divisible by meanPriceLookBack
        if (tickDelta < 0 && (tickDelta % int32(meanPriceLookBack) != 0)) meanTick--;

        // convert mean tick to mean sqrt price
        meanSqrtRatioX96 = TickMath.getSqrtRatioAtTick(meanTick);
    }
}
