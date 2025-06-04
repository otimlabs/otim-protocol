// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink-contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract InvertedPriceFeed is AggregatorV3Interface {
    AggregatorV3Interface public immutable originalPriceFeed;
    uint8 public immutable decimals;
    uint256 public immutable version;

    string public description;

    constructor(address _originalPriceFeed) {
        originalPriceFeed = AggregatorV3Interface(_originalPriceFeed);

        decimals = AggregatorV3Interface(_originalPriceFeed).decimals();
        description = string(abi.encodePacked("Inverted ", AggregatorV3Interface(_originalPriceFeed).description()));
        version = AggregatorV3Interface(_originalPriceFeed).version();
    }

    function getRoundData(uint80 roundId)
        external
        view
        returns (uint80 _roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        int256 originalAnswer;
        (_roundId, originalAnswer, startedAt, updatedAt, answeredInRound) = originalPriceFeed.getRoundData(roundId);

        // Invert the answer
        answer = int256(10 ** (decimals * 2)) / originalAnswer;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        int256 originalAnswer;
        (roundId, originalAnswer, startedAt, updatedAt, answeredInRound) = originalPriceFeed.latestRoundData();

        // Invert the answer
        answer = int256(10 ** (decimals * 2)) / originalAnswer;
    }
}
