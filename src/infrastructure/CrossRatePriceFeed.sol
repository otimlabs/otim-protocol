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
    /// @notice the numerator price feed (e.g., USDC/USD)
    AggregatorV3Interface public immutable numeratorFeed;
    /// @notice the denominator price feed (e.g., ETH/USD)
    AggregatorV3Interface public immutable denominatorFeed;

    /// @notice the number of decimals for the cross-rate price feed
    uint8 public immutable decimals;
    /// @notice the version of the price feed
    uint256 public immutable version;
    /// @notice the description of the price feed
    string public description;

    int256 private immutable scaleFactor;

    uint40 public immutable numeratorHeartbeat;
    uint40 public immutable denominatorHeartbeat;

    /// @notice Constructor for CrossRatePriceFeed
    /// @param numeratorFeedAddress - the price feed for the numerator (e.g., USDC/USD)
    /// @param denominatorFeedAddress - the price feed for the denominator (e.g., ETH/USD)
    constructor(
        address numeratorFeedAddress,
        address denominatorFeedAddress,
        uint40 _numeratorHeartbeat,
        uint40 _denominatorHeartbeat
    ) {
        numeratorFeed = AggregatorV3Interface(numeratorFeedAddress);
        denominatorFeed = AggregatorV3Interface(denominatorFeedAddress);

        // Create cross-rate description showing the full formula: "(numerator) / (denominator)"
        description =
            string(abi.encodePacked("(", numeratorFeed.description(), ") / (", denominatorFeed.description(), ")"));

        version = 1;

        numeratorHeartbeat = _numeratorHeartbeat;
        denominatorHeartbeat = _denominatorHeartbeat;

        // Use the higher precision for calculations to maintain accuracy
        uint8 numeratorDecimals = numeratorFeed.decimals();
        uint8 denominatorDecimals = denominatorFeed.decimals();

        if (numeratorDecimals != denominatorDecimals) {
            revert DecimalsMismatch();
        }

        decimals = numeratorDecimals;
        scaleFactor = int256(10 ** decimals);

        // check if the price feeds have been initialized
        // slither-disable-start unused-return
        (uint80 numeratorRoundId,,, uint256 numeratorUpdatedAt,) = numeratorFeed.latestRoundData();
        (uint80 denominatorRoundId,,, uint256 denominatorUpdatedAt,) = denominatorFeed.latestRoundData();
        // slither-disable-end unused-return

        if (numeratorRoundId == 0 || numeratorUpdatedAt == 0 || denominatorRoundId == 0 || denominatorUpdatedAt == 0) {
            revert PriceFeedNotInitialized();
        }
    }

    /// @notice get the cross-rate for a specific round (not supported)
    /// @dev historical round data is not supported for this cross-rate feed
    function getRoundData(uint80) external pure returns (uint80, int256, uint256, uint256, uint80) {
        revert GetRoundDataNotSupported();
    }

    /// @notice get the latest cross-rate
    /// @return roundId - the round ID
    /// @return answer - the cross-rate answer
    /// @return startedAt - when the round started
    /// @return updatedAt - when the round was updated
    /// @return answeredInRound - the round in which the answer was computed
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        int256 numeratorAnswer;

        // Get latest data from both feeds
        (roundId, numeratorAnswer, startedAt, updatedAt, answeredInRound) = numeratorFeed.latestRoundData();

        // slither-disable-next-line unused-return
        (, int256 denominatorAnswer, uint256 denominatorStartedAt, uint256 denominatorUpdatedAt,) =
            denominatorFeed.latestRoundData();

        if (
            updatedAt < block.timestamp - numeratorHeartbeat
                || denominatorUpdatedAt < block.timestamp - denominatorHeartbeat
        ) {
            revert StalePrice();
        }

        // Use the earlier timestamps
        updatedAt = denominatorUpdatedAt < updatedAt ? denominatorUpdatedAt : updatedAt;
        startedAt = denominatorStartedAt < startedAt ? denominatorStartedAt : startedAt;

        // Calculate cross-rate: (numerator / denominator)
        answer = numeratorAnswer * scaleFactor / denominatorAnswer;
    }
}
