// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/src/Test.sol";
import {CrossRatePriceFeed} from "../../../src/actions/fee-models/CrossRatePriceFeed.sol";
import {ICrossRatePriceFeed} from "../../../src/actions/fee-models/interfaces/ICrossRatePriceFeed.sol";
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

    /// @notice test constructor sets feeds correctly
    function test_constructor_setsFeeds() public view {
        assertEq(address(crossRatePriceFeed.numeratorFeed()), USDC_USD_FEED);
        assertEq(address(crossRatePriceFeed.denominatorFeed()), ETH_USD_FEED);
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

        assertGt(bytes(description).length, 0);

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

    /// @notice test constructor sets numerator heartbeat
    function test_constructor_setsNumeratorHeartbeat() public view {
        uint40 heartbeat = crossRatePriceFeed.numeratorHeartbeat();
        assertEq(heartbeat, USDC_USD_HEARTBEAT);
    }

    /// @notice test constructor sets denominator heartbeat
    function test_constructor_setsDenominatorHeartbeat() public view {
        uint40 heartbeat = crossRatePriceFeed.denominatorHeartbeat();
        assertEq(heartbeat, ETH_USD_HEARTBEAT);
    }

    /// @notice test getRoundData reverts for any round ID
    function testFuzz_getRoundData_revertsForAnyRoundId(uint80 roundId) public {
        vm.expectRevert(ICrossRatePriceFeed.GetRoundDataNotSupported.selector);
        crossRatePriceFeed.getRoundData(roundId);
    }

    /// @notice test latestRoundData reverts on divide by zero
    function test_latestRoundData_invalidNumeratorPrice() public {
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(8, 0);

        // set numerator answer to zero
        mockPriceFeed.updateRoundData(1, 0, block.timestamp, 1);

        crossRatePriceFeed =
            new CrossRatePriceFeed(address(mockPriceFeed), ETH_USD_FEED, USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);

        vm.expectRevert(ICrossRatePriceFeed.InvalidPrice.selector);
        crossRatePriceFeed.latestRoundData();
    }

    /// @notice test latestRoundData reverts on divide by zero
    function test_latestRoundData_invalidDenominatorPrice() public {
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(8, 0);

        // set denominator answer to zero
        mockPriceFeed.updateRoundData(1, 0, block.timestamp, 1);

        crossRatePriceFeed =
            new CrossRatePriceFeed(USDC_USD_FEED, address(mockPriceFeed), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);

        vm.expectRevert(ICrossRatePriceFeed.InvalidPrice.selector);
        crossRatePriceFeed.latestRoundData();
    }

    /// @notice test latestRoundData reverts on numerator feed stale price
    function test_latestRoundData_staleNumeratorPrice() public {
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(8, 0);

        // set numerator answer to zero
        mockPriceFeed.updateRoundData(1, 1, block.timestamp - USDC_USD_HEARTBEAT - 1, 1);

        crossRatePriceFeed =
            new CrossRatePriceFeed(address(mockPriceFeed), ETH_USD_FEED, USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);

        vm.expectRevert(ICrossRatePriceFeed.StalePrice.selector);
        crossRatePriceFeed.latestRoundData();
    }

    /// @notice test latestRoundData reverts on denominator feed stale price
    function test_latestRoundData_staleDenominatorPrice() public {
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(8, 0);

        // set denominator answer to zero
        mockPriceFeed.updateRoundData(1, 1, block.timestamp - ETH_USD_HEARTBEAT - 1, 1);

        crossRatePriceFeed =
            new CrossRatePriceFeed(USDC_USD_FEED, address(mockPriceFeed), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);

        vm.expectRevert(ICrossRatePriceFeed.StalePrice.selector);
        crossRatePriceFeed.latestRoundData();
    }

    /// @notice test latestRoundData reverts on overflow
    function test_latestRoundData_revertsOnOverflow() public {
        // Create a scenario that will definitely cause overflow
        // Use a very large number that will overflow when multiplied by the scale factor
        MockV3Aggregator overflowFeed = new MockV3Aggregator(8, type(int256).max);

        crossRatePriceFeed =
            new CrossRatePriceFeed(address(overflowFeed), ETH_USD_FEED, USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);

        // Contract should revert on overflow
        vm.expectRevert();
        crossRatePriceFeed.latestRoundData();
    }

    function test_latestRoundData_realValues() public {
        MockV3Aggregator numeratorFeed = new MockV3Aggregator(8, 99987137);
        MockV3Aggregator denominatorFeed = new MockV3Aggregator(8, 450076000000);

        crossRatePriceFeed = new CrossRatePriceFeed(
            address(numeratorFeed), address(denominatorFeed), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT
        );
        (, int256 answer,,,) = crossRatePriceFeed.latestRoundData();

        int256 expectedAnswer = 22215;

        assertEq(uint256(answer), uint256(expectedAnswer));
    }

    function testFuzz_latestRoundData_realValuesDecimals8(int256 numeratorAnswer, int256 denominatorAnswer) public {
        vm.assume(numeratorAnswer > 100_000 && numeratorAnswer < 100_000_000_000);
        vm.assume(denominatorAnswer > 0 && denominatorAnswer < 400_000_000_000_000);

        MockV3Aggregator numeratorFeed = new MockV3Aggregator(8, numeratorAnswer);
        MockV3Aggregator denominatorFeed = new MockV3Aggregator(8, denominatorAnswer);

        crossRatePriceFeed = new CrossRatePriceFeed(
            address(numeratorFeed), address(denominatorFeed), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT
        );
        (, int256 answer,,,) = crossRatePriceFeed.latestRoundData();

        int256 expectedAnswer = (numeratorAnswer * 10 ** 8) / denominatorAnswer;

        assertEq(uint256(answer), uint256(expectedAnswer));
    }

    function testFuzz_latestRoundData_realValuesDecimals18(int256 numeratorAnswer, int256 denominatorAnswer) public {
        vm.assume(numeratorAnswer > 1_000_000_000_000_000 && numeratorAnswer < 1_000_000_000_000_000_000_000_000);
        vm.assume(denominatorAnswer > 0 && denominatorAnswer < 4_000_000_000_000_000_000_000_000);

        MockV3Aggregator numeratorFeed = new MockV3Aggregator(18, numeratorAnswer);
        MockV3Aggregator denominatorFeed = new MockV3Aggregator(18, denominatorAnswer);

        crossRatePriceFeed = new CrossRatePriceFeed(
            address(numeratorFeed), address(denominatorFeed), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT
        );
        (, int256 answer,,,) = crossRatePriceFeed.latestRoundData();

        int256 expectedAnswer = (numeratorAnswer * 10 ** 18) / denominatorAnswer;

        assertEq(uint256(answer), uint256(expectedAnswer));
    }

    /// @notice test latestRoundData uses numerator feed's answered in round
    function test_latestRoundData_usesNumeratorAnsweredInRound() public view {
        (,,,, uint80 numeratorAnsweredInRound) = usdcUsdFeed.latestRoundData();
        (,,,, uint80 crossAnsweredInRound) = crossRatePriceFeed.latestRoundData();
        assertEq(crossAnsweredInRound, numeratorAnsweredInRound);
    }

    /// @notice test latestRoundData uses numerator feed's round ID
    function test_latestRoundData_usesEarliestRoundId() public view {
        (uint80 numeratorRoundId,,,,) = usdcUsdFeed.latestRoundData();
        (uint80 denominatorRoundId,,,,) = ethUsdFeed.latestRoundData();
        (uint80 crossRoundId,,,,) = crossRatePriceFeed.latestRoundData();

        uint80 expectedRoundId = numeratorRoundId < denominatorRoundId ? numeratorRoundId : denominatorRoundId;
        assertEq(crossRoundId, expectedRoundId);
    }

    /// @notice test latestRoundData uses earlier updated at timestamp
    function test_latestRoundData_usesEarlierUpdatedAt() public view {
        (,,, uint256 numeratorUpdatedAt,) = usdcUsdFeed.latestRoundData();
        (,,, uint256 denominatorUpdatedAt,) = ethUsdFeed.latestRoundData();
        (,,, uint256 crossUpdatedAt,) = crossRatePriceFeed.latestRoundData();

        uint256 expectedUpdatedAt =
            denominatorUpdatedAt < numeratorUpdatedAt ? denominatorUpdatedAt : numeratorUpdatedAt;

        assertEq(crossUpdatedAt, expectedUpdatedAt);
    }

    /// @notice test latestRoundData uses latest started at timestamp
    function test_latestRoundData_usesEarlierStartedAt() public view {
        (,, uint256 numeratorStartedAt,,) = usdcUsdFeed.latestRoundData();
        (,, uint256 denominatorStartedAt,,) = ethUsdFeed.latestRoundData();
        (,, uint256 crossStartedAt,,) = crossRatePriceFeed.latestRoundData();

        uint256 expectedStartedAt =
            denominatorStartedAt < numeratorStartedAt ? denominatorStartedAt : numeratorStartedAt;

        assertEq(crossStartedAt, expectedStartedAt);
    }

    /// @notice test started at is before or equal to updated at
    function test_latestRoundData_startedAtBeforeUpdatedAt() public view {
        (,, uint256 crossStartedAt, uint256 crossUpdatedAt,) = crossRatePriceFeed.latestRoundData();
        assertGe(crossUpdatedAt, crossStartedAt);
    }
}
