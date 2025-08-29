// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/src/Test.sol";

import {MockV3Aggregator} from "@chainlink-contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";

import {InvertedPriceFeed} from "../../src/infrastructure/InvertedPriceFeed.sol";

contract InvertedPriceFeedTest is Test {
    MockV3Aggregator public mockPriceFeed;
    InvertedPriceFeed public invertedMockPriceFeed;

    constructor() {
        mockPriceFeed = new MockV3Aggregator(8, 262420153200);
        invertedMockPriceFeed = new InvertedPriceFeed(address(mockPriceFeed));
    }

    function test_latestRoundData() public view {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            invertedMockPriceFeed.latestRoundData();

        assertEq(roundId, 1);
        assertEq(answer, 38106); // 1 / 2624.20153200
        assertEq(startedAt, block.timestamp);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 1);
    }
}
