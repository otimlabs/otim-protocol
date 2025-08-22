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
    AggregatorV3Interface public immutable NUMERATOR_FEED; // The feed in the numerator (e.g., USDC/USD)
    AggregatorV3Interface public immutable DENOMINATOR_FEED; // The feed in the denominator (e.g., ETH/USD)

    uint8 public immutable DECIMALS;
    uint256 public immutable VERSION;
    string public description;

    /// @notice Constructor for CrossRatePriceFeed
    /// @param _numeratorFeed The price feed for the numerator (e.g., USDC/USD)
    /// @param _denominatorFeed The price feed for the denominator (e.g., ETH/USD)
    constructor(address _numeratorFeed, address _denominatorFeed) {
        NUMERATOR_FEED = AggregatorV3Interface(_numeratorFeed);
        DENOMINATOR_FEED = AggregatorV3Interface(_denominatorFeed);

        // Use the higher precision for calculations to maintain accuracy
        uint8 numeratorDecimals = NUMERATOR_FEED.decimals();
        uint8 denominatorDecimals = DENOMINATOR_FEED.decimals();
        DECIMALS = numeratorDecimals > denominatorDecimals ? numeratorDecimals : denominatorDecimals;

        // Create cross-rate description showing the full formula: "(numerator) / (denominator)"
        description =
            string(abi.encodePacked("(", NUMERATOR_FEED.description(), ") / (", DENOMINATOR_FEED.description(), ")"));
        VERSION = 1;
    }

    /// @notice Get the cross-rate for a specific round
    /// @param _roundId The round ID to query
    /// @return roundId The round ID
    /// @return answer The cross-rate answer
    /// @return startedAt When the round started
    /// @return updatedAt When the round was updated
    /// @return answeredInRound The round in which the answer was computed
    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        int256 numeratorAnswer;
        int256 denominatorAnswer;

        // Get data from numerator feed (e.g., USDC/USD)
        (roundId, numeratorAnswer, startedAt, updatedAt, answeredInRound) = NUMERATOR_FEED.getRoundData(_roundId);

        // Get timestamp data from denominator feed to use the latest
        (,, uint256 denominatorStartedAt, uint256 denominatorUpdatedAt,) = DENOMINATOR_FEED.getRoundData(_roundId);

        // Use the later timestamps to ensure both feeds have data
        if (denominatorUpdatedAt > updatedAt) {
            updatedAt = denominatorUpdatedAt;
        }
        if (denominatorStartedAt > startedAt) {
            startedAt = denominatorStartedAt;
        }

        // Get the answer from denominator feed for the same round
        (, denominatorAnswer,,,) = DENOMINATOR_FEED.getRoundData(_roundId);

        // Calculate cross-rate: (numerator / denominator)
        answer = _calculateCrossRate(numeratorAnswer, denominatorAnswer);
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

        // Get latest data from numerator feed
        (roundId, numeratorAnswer, startedAt, updatedAt, answeredInRound) = NUMERATOR_FEED.latestRoundData();

        // Get timestamp data from denominator feed to use the latest
        (,, uint256 denominatorStartedAt, uint256 denominatorUpdatedAt,) = DENOMINATOR_FEED.latestRoundData();

        // Use the later timestamps to ensure both feeds have recent data
        if (denominatorUpdatedAt > updatedAt) {
            updatedAt = denominatorUpdatedAt;
        }
        if (denominatorStartedAt > startedAt) {
            startedAt = denominatorStartedAt;
        }

        // Get the latest answer from denominator feed
        (, denominatorAnswer,,,) = DENOMINATOR_FEED.latestRoundData();

        // Calculate cross-rate: (numerator / denominator)
        answer = _calculateCrossRate(numeratorAnswer, denominatorAnswer);
    }

    /// @notice Calculate the cross-rate by scaling both answers to the same precision
    /// @param numeratorAnswer The answer from the numerator feed
    /// @param denominatorAnswer The answer from the denominator feed
    /// @return The calculated cross-rate
    function _calculateCrossRate(int256 numeratorAnswer, int256 denominatorAnswer) internal view returns (int256) {
        // Get decimals directly from feeds (no need to store them)
        uint8 numeratorDecimals = NUMERATOR_FEED.decimals();
        uint8 denominatorDecimals = DENOMINATOR_FEED.decimals();

        int256 scaledNumeratorAnswer = numeratorAnswer;
        int256 scaledDenominatorAnswer = denominatorAnswer;

        // Scale to the higher precision
        if (numeratorDecimals < DECIMALS) {
            scaledNumeratorAnswer = numeratorAnswer * int256(10 ** (DECIMALS - numeratorDecimals));
        }
        if (denominatorDecimals < DECIMALS) {
            scaledDenominatorAnswer = denominatorAnswer * int256(10 ** (DECIMALS - denominatorDecimals));
        }

        return (scaledNumeratorAnswer * int256(10 ** DECIMALS)) / scaledDenominatorAnswer;
    }

    // Interface function implementations
    function numeratorFeed() external view returns (AggregatorV3Interface) {
        return NUMERATOR_FEED;
    }

    function denominatorFeed() external view returns (AggregatorV3Interface) {
        return DENOMINATOR_FEED;
    }

    function decimals() external view returns (uint8) {
        return DECIMALS;
    }

    function version() external view returns (uint256) {
        return VERSION;
    }
}
