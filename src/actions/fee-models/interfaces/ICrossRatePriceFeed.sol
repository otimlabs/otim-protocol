// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink-contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title ICrossRatePriceFeed
/// @author Otim Labs, Inc.
/// @notice Interface for the CrossRatePriceFeed contract that combines two price feeds to create a cross-rate
interface ICrossRatePriceFeed is AggregatorV3Interface {
    /// @notice Get the numerator price feed
    function numeratorFeed() external view returns (AggregatorV3Interface);

    /// @notice Get the denominator price feed
    function denominatorFeed() external view returns (AggregatorV3Interface);

    /// @notice Get the decimals precision of the cross-rate
    function decimals() external view returns (uint8);

    /// @notice Get the version of the price feed
    function version() external view returns (uint256);

    /// @notice Get the description of the cross-rate
    function description() external view returns (string memory);

    error GetRoundDataNotSupported();
    error Overflow();
    error DivisionByZero();
}
