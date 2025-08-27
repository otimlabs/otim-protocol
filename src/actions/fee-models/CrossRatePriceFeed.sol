// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink-contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ICrossRatePriceFeed} from "./interfaces/ICrossRatePriceFeed.sol";

/// @title CrossRatePriceFeed
/// @author Otim Labs, Inc.
/// @notice A dynamic price feed that combines two price feeds to create a cross-rate
/// @dev This contract takes two price feeds and calculates the cross-rate by canceling out the common denominator
///
/// Example: To get USDC/ETH rate from ETH/USD and USDC/USD feeds:
/// - Numerator Feed: USDC/USD = 1 (1 * 10^8 = 100000000)
/// - Denominator Feed: ETH/USD = 3000 (3000 * 10^8 = 300000000000)
/// - Cross Rate: USDC/ETH = (USDC/USD) / (ETH/USD) = 1/3000 = 0.000333...
///
/// The formula is: (numerator / denominator) to get the rate of numerator in terms of denominator
contract CrossRatePriceFeed is ICrossRatePriceFeed {
    AggregatorV3Interface public immutable numeratorFeedContract; // The feed in the numerator (e.g., USDC/USD)
    AggregatorV3Interface public immutable denominatorFeedContract; // The feed in the denominator (e.g., ETH/USD)

    uint8 public immutable decimalsValue;
    uint256 public immutable versionValue;
    string public description;

    /// @notice Constructor for CrossRatePriceFeed
    /// @param numeratorFeedAddress The price feed for the numerator (e.g., USDC/USD)
    /// @param denominatorFeedAddress The price feed for the denominator (e.g., ETH/USD)
    constructor(address numeratorFeedAddress, address denominatorFeedAddress) {
        numeratorFeedContract = AggregatorV3Interface(numeratorFeedAddress);
        denominatorFeedContract = AggregatorV3Interface(denominatorFeedAddress);

        // Use the higher precision for calculations to maintain accuracy
        uint8 numeratorDecimals = numeratorFeedContract.decimals();
        uint8 denominatorDecimals = denominatorFeedContract.decimals();
        decimalsValue = numeratorDecimals > denominatorDecimals ? numeratorDecimals : denominatorDecimals;

        // Create cross-rate description showing the full formula: "(numerator) / (denominator)"
        description = string(
            abi.encodePacked(
                "(", numeratorFeedContract.description(), ") / (", denominatorFeedContract.description(), ")"
            )
        );
        versionValue = 1;
    }

    /// @notice Get the cross-rate for a specific round (not supported)
    /// @dev Historical round data is not supported for cross-rate feeds.
    function getRoundData(uint80 /* _roundId */ )
        external
        pure
        returns (
            uint80, /* roundId */
            int256, /* answer */
            uint256, /* startedAt */
            uint256, /* updatedAt */
            uint80 /* answeredInRound */
        )
    {
        revert GetRoundDataNotSupported();
    }

    /// @notice Get the latest cross-rate
    /// @return roundId The round ID
    /// @return answer The cross-rate answer
    /// @return startedAt When the round started
    /// @return updatedAt When the round was updated
    /// @return answeredInRound The round in which the answer was computed
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        int256 numeratorAnswer;
        int256 denominatorAnswer;

        // Get latest data from both feeds
        (roundId, numeratorAnswer, startedAt, updatedAt, answeredInRound) = numeratorFeedContract.latestRoundData();

        uint256 denominatorStartedAt;
        uint256 denominatorUpdatedAt;
        uint80 denominatorRoundId;
        uint80 denominatorAnsweredInRound;
        (denominatorRoundId, denominatorAnswer, denominatorStartedAt, denominatorUpdatedAt, denominatorAnsweredInRound)
        = denominatorFeedContract.latestRoundData();

        // Use the later timestamps to ensure both feeds have recent data
        if (denominatorUpdatedAt > updatedAt) {
            updatedAt = denominatorUpdatedAt;
        }
        if (denominatorStartedAt > startedAt) {
            startedAt = denominatorStartedAt;
        }

        // Calculate cross-rate: (numerator / denominator)
        answer = _calculateCrossRate(numeratorAnswer, denominatorAnswer);
    }

    /// @notice Calculate the cross-rate by scaling both answers to the same precision
    /// @param numeratorAnswer The answer from the numerator feed
    /// @param denominatorAnswer The answer from the denominator feed
    /// @return The calculated cross-rate
    function _calculateCrossRate(int256 numeratorAnswer, int256 denominatorAnswer) internal view returns (int256) {
        // Get decimals from feeds
        uint8 numeratorDecimals = numeratorFeedContract.decimals();
        uint8 denominatorDecimals = denominatorFeedContract.decimals();

        // Use the higher of the two decimals as target precision
        uint8 targetPrecision = numeratorDecimals > denominatorDecimals ? numeratorDecimals : denominatorDecimals;

        // Scale numerator to target precision (only if needed)
        int256 scaledNumerator = numeratorAnswer;
        if (numeratorDecimals != targetPrecision) {
            // Scale up: multiply by 10^(targetPrecision - numeratorDecimals)
            uint256 scaleFactor = 10 ** (targetPrecision - numeratorDecimals);
            if (numeratorAnswer > type(int256).max / int256(scaleFactor)) revert Overflow();
            scaledNumerator = numeratorAnswer * int256(scaleFactor);
        }

        // Scale denominator to target precision (only if needed)
        int256 scaledDenominator = denominatorAnswer;
        if (denominatorDecimals != targetPrecision) {
            // Scale up: multiply by 10^(targetPrecision - denominatorDecimals)
            uint256 scaleFactor = 10 ** (targetPrecision - denominatorDecimals);
            if (denominatorAnswer > type(int256).max / int256(scaleFactor)) revert Overflow();
            scaledDenominator = denominatorAnswer * int256(scaleFactor);
        }

        // Check for division by zero
        if (scaledDenominator == 0) revert DivisionByZero();

        // Calculate final result ensuring the result has targetPrecision decimals
        int256 finalNumerator = scaledNumerator * int256(10 ** targetPrecision);

        return finalNumerator / scaledDenominator;
    }

    // Interface function implementations
    function numeratorFeed() external view returns (AggregatorV3Interface) {
        return numeratorFeedContract;
    }

    function denominatorFeed() external view returns (AggregatorV3Interface) {
        return denominatorFeedContract;
    }

    function decimals() external view returns (uint8) {
        return decimalsValue;
    }

    function version() external view returns (uint256) {
        return versionValue;
    }
}
