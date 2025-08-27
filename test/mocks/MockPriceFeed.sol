// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink-contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title MockPriceFeed
/// @notice A mock price feed for testing with configurable data
contract MockPriceFeed is AggregatorV3Interface {
    int256 public mockAnswer;
    uint80 public mockRoundId;
    uint8 public mockDecimals;
    uint256 public mockVersion;
    uint256 public mockStartedAt;
    uint256 public mockUpdatedAt;
    uint80 public mockAnsweredInRound;
    string public mockDescription;

    function setMockData(
        uint80 _roundId,
        int256 _answer,
        uint8 _decimals,
        uint256 _version,
        uint256 _updatedAt,
        uint80 _answeredInRound
    ) external {
        mockRoundId = _roundId;
        mockAnswer = _answer;
        mockDecimals = _decimals;
        mockVersion = _version;
        mockStartedAt = _updatedAt - 3600; // 1 hour before
        mockUpdatedAt = _updatedAt;
        mockAnsweredInRound = _answeredInRound;
        mockDescription = "Mock Price Feed";
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (mockRoundId, mockAnswer, mockStartedAt, mockUpdatedAt, mockAnsweredInRound);
    }

    function getRoundData(uint80 /* _roundId */ )
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (mockRoundId, mockAnswer, mockStartedAt, mockUpdatedAt, mockAnsweredInRound);
    }

    function decimals() external view returns (uint8) {
        return mockDecimals;
    }

    function version() external view returns (uint256) {
        return mockVersion;
    }

    function description() external view returns (string memory) {
        return mockDescription;
    }
}
