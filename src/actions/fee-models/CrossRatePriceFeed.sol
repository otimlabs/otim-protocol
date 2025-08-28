// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink-contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ICrossRatePriceFeed} from "./interfaces/ICrossRatePriceFeed.sol";

/// @title CrossRatePriceFeed
/// @author Otim Labs, Inc.
/// @notice a contract that combines two price feeds to create a cross-rate price feed
contract CrossRatePriceFeed is ICrossRatePriceFeed {
    /// @notice the numerator price feed (e.g., USDC/USD)
    AggregatorV3Interface public immutable numeratorFeed;
    /// @notice the denominator price feed (e.g., ETH/USD)
    AggregatorV3Interface public immutable denominatorFeed;

    /// @notice the number of decimals of the cross-rate price feed
    uint8 public immutable decimals;
    /// @notice the version of the price feed
    uint256 public constant version = 1;
    /// @notice the description of the price feed
    string public description;

    /// @notice the heartbeat of the numerator price feed
    uint40 public immutable numeratorHeartbeat;
    /// @notice the heartbeat of the denominator price feed
    uint40 public immutable denominatorHeartbeat;

    /// @notice the scale factor used to maintain decimal precision when calculating the cross-rate
    int256 private immutable scaleFactor;

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

        description =
            string(abi.encodePacked("(", numeratorFeed.description(), ") / (", denominatorFeed.description(), ")"));

        uint8 numeratorDecimals = numeratorFeed.decimals();
        uint8 denominatorDecimals = denominatorFeed.decimals();

        if (numeratorDecimals != denominatorDecimals) {
            revert DecimalsMismatch();
        }

        decimals = numeratorDecimals;
        scaleFactor = int256(10 ** decimals);

        numeratorHeartbeat = _numeratorHeartbeat;
        denominatorHeartbeat = _denominatorHeartbeat;

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

    /// @notice get the latest cross-rate price
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
        (roundId, answer, startedAt, updatedAt, answeredInRound) = numeratorFeed.latestRoundData();

        // slither-disable-next-line unused-return
        (, int256 denominatorAnswer, uint256 denominatorStartedAt, uint256 denominatorUpdatedAt,) =
            denominatorFeed.latestRoundData();

        if (
            updatedAt < block.timestamp - numeratorHeartbeat
                || denominatorUpdatedAt < block.timestamp - denominatorHeartbeat
        ) {
            revert StalePrice();
        }

        updatedAt = denominatorUpdatedAt < updatedAt ? denominatorUpdatedAt : updatedAt;
        startedAt = denominatorStartedAt < startedAt ? denominatorStartedAt : startedAt;

        answer *= scaleFactor;
        answer /= denominatorAnswer;
    }
}
