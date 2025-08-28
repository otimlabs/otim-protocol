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

    /// @notice the number of decimals for the numerator price feed
    uint8 public immutable numeratorDecimals;
    /// @notice the number of decimals for the denominator price feed
    uint8 public immutable denominatorDecimals;

    bool private immutable numeratorDecimalsGreater;
    uint8 private immutable decimalDifference;
    int256 private immutable scaleFactor;

    /// @notice the number of decimals for the cross-rate price feed
    uint8 public immutable decimals;
    /// @notice the version of the price feed
    uint256 public immutable version;
    /// @notice the description of the price feed
    string public description;

    /// @notice Constructor for CrossRatePriceFeed
    /// @param numeratorFeedAddress - the price feed for the numerator (e.g., USDC/USD)
    /// @param denominatorFeedAddress - the price feed for the denominator (e.g., ETH/USD)
    constructor(address numeratorFeedAddress, address denominatorFeedAddress) {
        numeratorFeed = AggregatorV3Interface(numeratorFeedAddress);
        denominatorFeed = AggregatorV3Interface(denominatorFeedAddress);

        // Use the higher precision for calculations to maintain accuracy
        numeratorDecimals = numeratorFeed.decimals();
        denominatorDecimals = denominatorFeed.decimals();

        if (numeratorDecimals > denominatorDecimals) {
            numeratorDecimalsGreater = true;
            decimals = numeratorDecimals;
            decimalDifference = numeratorDecimals - denominatorDecimals;
            scaleFactor = int256(10 ** decimalDifference);
        } else {
            decimals = denominatorDecimals;
            decimalDifference = denominatorDecimals - numeratorDecimals;
            scaleFactor = int256(10 ** decimalDifference);
        }

        // check if the price feeds have been initialized
        // slither-disable-start unused-return
        (uint80 numeratorRoundId,,, uint256 numeratorUpdatedAt,) = numeratorFeed.latestRoundData();
        (uint80 denominatorRoundId,,, uint256 denominatorUpdatedAt,) = denominatorFeed.latestRoundData();
        // slither-disable-end unused-return

        if (numeratorRoundId == 0 || numeratorUpdatedAt == 0) {
            revert NumeratorPriceFeedNotInitialized();
        }

        if (denominatorRoundId == 0 || denominatorUpdatedAt == 0) {
            revert DenominatorPriceFeedNotInitialized();
        }

        // Create cross-rate description showing the full formula: "(numerator) / (denominator)"
        description =
            string(abi.encodePacked("(", numeratorFeed.description(), ") / (", denominatorFeed.description(), ")"));
        version = 1;
    }

    /// @notice get the cross-rate for a specific round (not supported)
    /// @dev historical round data is not supported for cross-rate feeds.
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
        int256 denominatorAnswer;

        // Get latest data from both feeds
        (roundId, numeratorAnswer, startedAt, updatedAt, answeredInRound) = numeratorFeed.latestRoundData();

        uint256 denominatorStartedAt;
        uint256 denominatorUpdatedAt;
        uint80 denominatorRoundId;
        uint80 denominatorAnsweredInRound;
        (denominatorRoundId, denominatorAnswer, denominatorStartedAt, denominatorUpdatedAt, denominatorAnsweredInRound)
        = denominatorFeed.latestRoundData();

        // Use the later timestamps to ensure both feeds have recent data
        // TODO: this should use the earliest timestamp to make sure we don't use stale data
        if (denominatorUpdatedAt > updatedAt) {
            updatedAt = denominatorUpdatedAt;
        }
        if (denominatorStartedAt > startedAt) {
            startedAt = denominatorStartedAt;
        }

        // Calculate cross-rate: (numerator / denominator)
        answer = _calculateCrossRate(numeratorAnswer, denominatorAnswer);
    }

    /// @notice calculate the cross-rate by scaling both answers to the same precision
    /// @param numeratorAnswer - the answer from the numerator feed
    /// @param denominatorAnswer - the answer from the denominator feed
    /// @return - the calculated cross-rate
    function _calculateCrossRate(int256 numeratorAnswer, int256 denominatorAnswer) internal view returns (int256) {
        if (decimalDifference > 0) {
            if (numeratorDecimalsGreater) {
                if (denominatorAnswer > type(int256).max / scaleFactor) revert Overflow();
                denominatorAnswer *= scaleFactor;
            } else {
                if (numeratorAnswer > type(int256).max / scaleFactor) revert Overflow();
                numeratorAnswer *= scaleFactor;
            }
        }

        return numeratorAnswer * int256(10 ** decimals) / denominatorAnswer;
    }
}
