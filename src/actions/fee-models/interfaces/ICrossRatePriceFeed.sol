// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink-contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title ICrossRatePriceFeed
/// @author Otim Labs, Inc.
/// @notice Interface for the CrossRatePriceFeed contract that combines two price feeds to create a cross-rate
interface ICrossRatePriceFeed is AggregatorV3Interface {
    error PriceFeedNotInitialized();
    error DecimalsMismatch();
    error GetRoundDataNotSupported();
    error InvalidPrice();
    error StalePrice();

    /// @notice Get the numerator price feed
    function numeratorFeed() external view returns (AggregatorV3Interface);

    /// @notice Get the denominator price feed
    function denominatorFeed() external view returns (AggregatorV3Interface);

    /// @notice Get the heartbeat of the numerator price feed
    function numeratorHeartbeat() external view returns (uint40);

    /// @notice Get the heartbeat of the denominator price feed
    function denominatorHeartbeat() external view returns (uint40);

    /// @notice Get the decimals precision of the cross-rate
    function decimals() external view returns (uint8);

    /// @notice Get the version of the price feed
    function version() external view returns (uint256);

    /// @notice Get the description of the cross-rate
    function description() external view returns (string memory);

    /// @notice [Not Supported] get the cross-rate for a specific round
    function getRoundData(uint80) external pure returns (uint80, int256, uint256, uint256, uint80);

    /// @notice get the latest cross-rate price
    /// @return roundId - the round ID
    /// @return answer - the cross-rate answer
    /// @return startedAt - when the round started (the earlier of the two feeds)
    /// @return updatedAt - when the round was updated (the earlier of the two feeds)
    /// @return answeredInRound - the round in which the answer was computed (earlier of the two feeds)
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
