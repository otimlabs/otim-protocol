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
    AggregatorV3Interface public immutable _numeratorFeed; // The feed in the numerator (e.g., USDC/USD)
    AggregatorV3Interface public immutable _denominatorFeed; // The feed in the denominator (e.g., ETH/USD)

    uint8 public immutable _decimals;
    uint256 public immutable _version;
    string public description;

    /// @notice Constructor for CrossRatePriceFeed
    /// @param numeratorFeedAddress The price feed for the numerator (e.g., USDC/USD)
    /// @param denominatorFeedAddress The price feed for the denominator (e.g., ETH/USD)
    constructor(address numeratorFeedAddress, address denominatorFeedAddress) {
        _numeratorFeed = AggregatorV3Interface(numeratorFeedAddress);
        _denominatorFeed = AggregatorV3Interface(denominatorFeedAddress);

        // Use the higher precision for calculations to maintain accuracy
        uint8 numeratorDecimals = _numeratorFeed.decimals();
        uint8 denominatorDecimals = _denominatorFeed.decimals();
        _decimals = numeratorDecimals > denominatorDecimals ? numeratorDecimals : denominatorDecimals;

        // Create cross-rate description showing the full formula: "(numerator) / (denominator)"
        description =
            string(abi.encodePacked("(", _numeratorFeed.description(), ") / (", _denominatorFeed.description(), ")"));
        _version = 1;
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
        (roundId, numeratorAnswer, startedAt, updatedAt, answeredInRound) = _numeratorFeed.latestRoundData();

        uint256 denominatorStartedAt;
        uint256 denominatorUpdatedAt;
        (, denominatorAnswer, denominatorStartedAt, denominatorUpdatedAt,) = _denominatorFeed.latestRoundData();

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
        // Get decimals directly from feeds (no need to store them)
        uint8 numeratorDecimals = _numeratorFeed.decimals();
        uint8 denominatorDecimals = _denominatorFeed.decimals();

        int256 scaledNumeratorAnswer = numeratorAnswer;
        int256 scaledDenominatorAnswer = denominatorAnswer;

        // Scale to the higher precision
        if (numeratorDecimals < _decimals) {
            scaledNumeratorAnswer = numeratorAnswer * int256(10 ** (_decimals - numeratorDecimals));
        }
        if (denominatorDecimals < _decimals) {
            scaledDenominatorAnswer = denominatorAnswer * int256(10 ** (_decimals - denominatorDecimals));
        }

        return (scaledNumeratorAnswer * int256(10 ** _decimals)) / scaledDenominatorAnswer;
    }

    // Interface function implementations
    function numeratorFeed() external view returns (AggregatorV3Interface) {
        return _numeratorFeed;
    }

    function denominatorFeed() external view returns (AggregatorV3Interface) {
        return _denominatorFeed;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function version() external view returns (uint256) {
        return _version;
    }
}
