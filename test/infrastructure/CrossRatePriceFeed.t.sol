// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/src/Test.sol";
import {stdError} from "forge-std/src/StdError.sol";
import {CrossRatePriceFeed} from "../../src/infrastructure/CrossRatePriceFeed.sol";
import {ICrossRatePriceFeed} from "../../src/infrastructure/interfaces/ICrossRatePriceFeed.sol";
import {AggregatorV3Interface} from "@chainlink-contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {MockV3Aggregator} from "@chainlink-contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";

contract CrossRatePriceFeedTest is Test {
    // Sepolia price feed addresses
    address constant ETH_USD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address constant USDC_USD_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;

    CrossRatePriceFeed public crossRatePriceFeed;
    AggregatorV3Interface public ethUsdFeed;
    AggregatorV3Interface public usdcUsdFeed;

    uint40 constant ETH_USD_HEARTBEAT = 3600;
    uint40 constant USDC_USD_HEARTBEAT = 86400;

    constructor() {
        string memory rpcUrl = vm.envOr("SEPOLIA_RPC_URL", vm.rpcUrl("sepolia"));
        vm.createSelectFork(rpcUrl);

        // Initialize price feeds
        ethUsdFeed = AggregatorV3Interface(ETH_USD_FEED);
        usdcUsdFeed = AggregatorV3Interface(USDC_USD_FEED);

        // Deploy CrossRatePriceFeed with USDC/USD as numerator and ETH/USD as denominator
        // This will create a USDC/ETH rate
        crossRatePriceFeed = new CrossRatePriceFeed(USDC_USD_FEED, ETH_USD_FEED, USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);
    }

    /// @notice Helper function to warp time so the price feeds are fresh
    function _warpToFreshPrice() internal {
        (,,, uint256 numeratorUpdatedAt,) = usdcUsdFeed.latestRoundData();
        (,,, uint256 denominatorUpdatedAt,) = ethUsdFeed.latestRoundData();

        // Warp to just before the earliest feed expiration
        uint256 numeratorExpiry = numeratorUpdatedAt + USDC_USD_HEARTBEAT;
        uint256 denominatorExpiry = denominatorUpdatedAt + ETH_USD_HEARTBEAT;
        uint256 minExpiry = numeratorExpiry < denominatorExpiry ? numeratorExpiry : denominatorExpiry;
        vm.warp(minExpiry - 1);
    }

    /// @notice test constructor reverts with zero numerator feed
    function test_constructor_numeratorZeroAddress() public {
        vm.expectRevert();
        new CrossRatePriceFeed(address(0), ETH_USD_FEED, USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);
    }

    /// @notice test constructor reverts with zero denominator feed
    function test_constructor_denominatorZeroAddress() public {
        vm.expectRevert();
        new CrossRatePriceFeed(USDC_USD_FEED, address(0), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);
    }

    /// @notice test constructor sets description
    function test_constructor_setsDescription() public view {
        string memory description = crossRatePriceFeed.description();

        string memory expectedDescription =
            string(abi.encodePacked("(", usdcUsdFeed.description(), ") / (", ethUsdFeed.description(), ")"));

        assertEq(description, expectedDescription);
    }

    /// @notice test constructor sets version
    function test_constructor_setsVersion() public view {
        uint256 version = crossRatePriceFeed.version();

        assertEq(version, 1);
    }

    /// @notice test constructor sets decimals
    function test_constructor_setsDecimals() public view {
        uint8 decimals = crossRatePriceFeed.decimals();

        uint8 numeratorDecimals = usdcUsdFeed.decimals();
        uint8 denominatorDecimals = ethUsdFeed.decimals();

        assertEq(decimals, numeratorDecimals);
        assertEq(decimals, denominatorDecimals);
    }

    /// @notice test constructor reverts with decimals mismatch
    function test_constructor_decimalMismatch() public {
        MockV3Aggregator mockPriceFeed8 = new MockV3Aggregator(8, 0);
        MockV3Aggregator mockPriceFeed18 = new MockV3Aggregator(18, 0);

        vm.expectRevert(ICrossRatePriceFeed.DecimalsMismatch.selector);
        new CrossRatePriceFeed(address(mockPriceFeed8), address(mockPriceFeed18), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);
    }

    /// @notice test constructor reverts with numerator feed not initialized
    function test_constructor_numeratorFeedNotInitialized() public {
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(8, 0);

        // set numerator round id to zero
        mockPriceFeed.updateRoundData(0, 0, 0, 0);

        vm.expectRevert(ICrossRatePriceFeed.PriceFeedNotInitialized.selector);
        new CrossRatePriceFeed(address(mockPriceFeed), ETH_USD_FEED, USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);
    }

    /// @notice test constructor reverts with denominator feed not initialized
    function test_constructor_denominatorFeedNotInitialized() public {
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(8, 0);

        // set denominator round id to zero
        mockPriceFeed.updateRoundData(0, 0, 0, 0);

        vm.expectRevert(ICrossRatePriceFeed.PriceFeedNotInitialized.selector);
        new CrossRatePriceFeed(USDC_USD_FEED, address(mockPriceFeed), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);
    }

    /// @notice test getRoundData reverts for any round ID
    function testFuzz_getRoundData_revertsForAnyRoundId(uint80 roundId) public {
        vm.expectRevert(ICrossRatePriceFeed.GetRoundDataNotSupported.selector);
        crossRatePriceFeed.getRoundData(roundId);
    }

    /// @notice test latestRoundData returns roundId == 1
    function test_latestRoundData_roundIdOne() public {
        _warpToFreshPrice();
        (uint80 roundId,,,,) = crossRatePriceFeed.latestRoundData();

        assertEq(roundId, 1);
    }

    /// @notice test latestRoundData uses earlier updated at timestamp
    function test_latestRoundData_usesEarlierUpdatedAt() public {
        _warpToFreshPrice();
        (,,, uint256 numeratorUpdatedAt,) = usdcUsdFeed.latestRoundData();
        (,,, uint256 denominatorUpdatedAt,) = ethUsdFeed.latestRoundData();
        (,,, uint256 crossUpdatedAt,) = crossRatePriceFeed.latestRoundData();

        uint256 expectedUpdatedAt =
            denominatorUpdatedAt < numeratorUpdatedAt ? denominatorUpdatedAt : numeratorUpdatedAt;

        assertEq(crossUpdatedAt, expectedUpdatedAt);
    }

    /// @notice test latestRoundData returns startedAt == 0
    function test_latestRoundData_startedAtZero() public {
        _warpToFreshPrice();
        (,, uint256 startedAt,,) = crossRatePriceFeed.latestRoundData();

        assertEq(startedAt, 0);
    }

    /// @notice test latestRoundData returns answeredInRound == 0
    function test_latestRoundData_answeredInRoundZero() public {
        _warpToFreshPrice();
        (,,,, uint80 answeredInRound) = crossRatePriceFeed.latestRoundData();

        assertEq(answeredInRound, 0);
    }

    /// @notice test latestRoundData reverts on divide by zero
    function test_latestRoundData_invalidNumeratorPrice(int256 numeratorAnswer) public {
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(8, 0);

        numeratorAnswer = bound(numeratorAnswer, type(int256).min, 0);

        // set numerator answer to zero
        mockPriceFeed.updateRoundData(1, numeratorAnswer, block.timestamp, 1);

        crossRatePriceFeed =
            new CrossRatePriceFeed(address(mockPriceFeed), ETH_USD_FEED, USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);

        vm.expectRevert(ICrossRatePriceFeed.InvalidPrice.selector);
        crossRatePriceFeed.latestRoundData();
    }

    /// @notice test latestRoundData reverts on divide by zero
    function test_latestRoundData_invalidDenominatorPrice(int256 denominatorAnswer) public {
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(8, 0);

        denominatorAnswer = bound(denominatorAnswer, type(int256).min, 0);

        // set denominator answer to zero
        mockPriceFeed.updateRoundData(1, denominatorAnswer, block.timestamp, 1);

        crossRatePriceFeed =
            new CrossRatePriceFeed(USDC_USD_FEED, address(mockPriceFeed), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);

        vm.expectRevert(ICrossRatePriceFeed.InvalidPrice.selector);
        crossRatePriceFeed.latestRoundData();
    }

    /// @notice test latestRoundData reverts on numerator feed stale price
    function test_latestRoundData_staleNumeratorPrice(uint256 numeratorUpdatedAt) public {
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(8, 0);

        // can't be zero or constructor will revert with PriceFeedNotInitialized
        numeratorUpdatedAt = bound(numeratorUpdatedAt, 1, block.timestamp - USDC_USD_HEARTBEAT - 1);

        // set numerator answer to zero
        mockPriceFeed.updateRoundData(1, 1, numeratorUpdatedAt, 1);

        crossRatePriceFeed =
            new CrossRatePriceFeed(address(mockPriceFeed), ETH_USD_FEED, USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);

        vm.expectRevert(ICrossRatePriceFeed.StalePrice.selector);
        crossRatePriceFeed.latestRoundData();
    }

    /// @notice test latestRoundData reverts on denominator feed stale price
    function test_latestRoundData_staleDenominatorPrice(uint256 denominatorUpdatedAt) public {
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(8, 0);

        // can't be zero or constructor will revert with PriceFeedNotInitialized
        denominatorUpdatedAt = bound(denominatorUpdatedAt, 1, block.timestamp - ETH_USD_HEARTBEAT - 1);

        // set denominator answer to zero
        mockPriceFeed.updateRoundData(1, 1, denominatorUpdatedAt, 1);

        crossRatePriceFeed =
            new CrossRatePriceFeed(USDC_USD_FEED, address(mockPriceFeed), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);

        vm.expectRevert(ICrossRatePriceFeed.StalePrice.selector);
        crossRatePriceFeed.latestRoundData();
    }

    /// @notice test latestRoundData reverts on overflow
    function test_latestRoundData_revertsOnOverflow(int256 numeratorAnswer) public {
        numeratorAnswer = bound(numeratorAnswer, type(int256).max / int256(10 ** 8) + 1, type(int256).max);

        MockV3Aggregator overflowFeed = new MockV3Aggregator(8, numeratorAnswer);

        crossRatePriceFeed =
            new CrossRatePriceFeed(address(overflowFeed), ETH_USD_FEED, USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);

        _warpToFreshPrice();
        vm.expectRevert(stdError.arithmeticError);
        crossRatePriceFeed.latestRoundData();
    }

    /// @notice test latestRoundData returns correct answer with values from Sepolia price feeds
    function test_latestRoundData_realValuesFork() public {
        _warpToFreshPrice();
        (, int256 numeratorAnswer,,,) = usdcUsdFeed.latestRoundData();
        (, int256 denominatorAnswer,,,) = ethUsdFeed.latestRoundData();
        (, int256 answer,,,) = crossRatePriceFeed.latestRoundData();

        uint8 decimals = crossRatePriceFeed.decimals();

        int256 expectedAnswer = numeratorAnswer * int256(10 ** decimals) / denominatorAnswer;

        assertEq(answer, expectedAnswer);
    }

    /// @notice test latestRoundData returns correct answer with fuzzed values
    function test_latestRoundData_realValuesFuzz8(int256 numeratorAnswer, int256 denominatorAnswer) public {
        // USDC/USD should be approximately $1.00 (100_000_000)
        int256 expectedNumeratorAnswer = 100_000_000;
        // ETH/USD should be approximately $4500.00 (450_000_000_000)
        int256 expectedDenominatorAnswer = 450_000_000_000;

        // limit the possible numerator values by this variance factor
        int256 numeratorVariance = 1_000_000;
        // limit the possible denominator values by this variance factor
        int256 denominatorVariance = 1_000_000_000;

        numeratorAnswer = bound(
            numeratorAnswer, expectedNumeratorAnswer / numeratorVariance, expectedNumeratorAnswer * numeratorVariance
        );
        denominatorAnswer = bound(
            denominatorAnswer,
            expectedDenominatorAnswer / denominatorVariance,
            expectedDenominatorAnswer * denominatorVariance
        );

        MockV3Aggregator numeratorFeed = new MockV3Aggregator(8, numeratorAnswer);
        MockV3Aggregator denominatorFeed = new MockV3Aggregator(8, denominatorAnswer);

        crossRatePriceFeed = new CrossRatePriceFeed(
            address(numeratorFeed), address(denominatorFeed), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT
        );

        (, int256 answer,,,) = crossRatePriceFeed.latestRoundData();

        int256 expectedAnswer = (numeratorAnswer * 10 ** 8) / denominatorAnswer;

        assertEq(uint256(answer), uint256(expectedAnswer));
    }

    function test_latestRoundData_realValuesFuzz18(int256 numeratorAnswer, int256 denominatorAnswer) public {
        // USDC/USD should be approximately $1.00
        int256 expectedNumeratorAnswer = 1_000_000_000_000_000_000;
        // ETH/USD should be approximately $4500.00
        int256 expectedDenominatorAnswer = 4_500_000_000_000_000_000_000;

        // limit the possible numerator values by this variance factor
        int256 numeratorVariance = 1_000_000;
        // limit the possible denominator values by this variance factor
        int256 denominatorVariance = 1_000_000_000;

        numeratorAnswer = bound(
            numeratorAnswer, expectedNumeratorAnswer / numeratorVariance, expectedNumeratorAnswer * numeratorVariance
        );
        denominatorAnswer = bound(
            denominatorAnswer,
            expectedDenominatorAnswer / denominatorVariance,
            expectedDenominatorAnswer * denominatorVariance
        );

        MockV3Aggregator numeratorFeed = new MockV3Aggregator(18, numeratorAnswer);
        MockV3Aggregator denominatorFeed = new MockV3Aggregator(18, denominatorAnswer);

        crossRatePriceFeed = new CrossRatePriceFeed(
            address(numeratorFeed), address(denominatorFeed), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT
        );
        (, int256 answer,,,) = crossRatePriceFeed.latestRoundData();

        int256 expectedAnswer = (numeratorAnswer * 10 ** 18) / denominatorAnswer;

        assertEq(uint256(answer), uint256(expectedAnswer));
    }
}
