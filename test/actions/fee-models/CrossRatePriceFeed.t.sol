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

    /// @notice test constructor calculates decimals as max of both feeds
    function test_constructor_calculatesDecimals() public view {
        uint8 numeratorDecimals = usdcUsdFeed.decimals();
        uint8 denominatorDecimals = ethUsdFeed.decimals();
        uint8 expectedDecimals = numeratorDecimals > denominatorDecimals ? numeratorDecimals : denominatorDecimals;
        assertEq(crossRatePriceFeed.decimals(), expectedDecimals);
    }

    /// @notice test constructor reverts with zero numerator feed
    function test_constructor_revertsZeroNumerator() public {
        vm.expectRevert();
        new CrossRatePriceFeed(address(0), ETH_USD_FEED, USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);
    }

    /// @notice test constructor reverts with zero denominator feed
    function test_constructor_revertsZeroDenominator() public {
        vm.expectRevert();
        new CrossRatePriceFeed(USDC_USD_FEED, address(0), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);
    }

    // ============ MATHEMATICAL EDGE CASE TESTS ============

    /// @notice test division by zero protection
    function test_latestRoundData_handlesZeroDenominator() public {
        MockV3Aggregator zeroDenominatorFeed = new MockV3Aggregator(8, 0);

        // set denominator answer to zero
        zeroDenominatorFeed.updateRoundData(1, 0, block.timestamp, 1);

        CrossRatePriceFeed zeroCrossRate =
            new CrossRatePriceFeed(USDC_USD_FEED, address(zeroDenominatorFeed), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);

        vm.expectRevert();
        zeroCrossRate.latestRoundData();
    }

    /// @notice test extreme price ratios
    function test_latestRoundData_handlesExtremeRatios() public {
        MockV3Aggregator extremeFeed = new MockV3Aggregator(8, 0);

        // set denominator answer to very small
        extremeFeed.updateRoundData(1, 1, block.timestamp, 1); // very small denominator

        CrossRatePriceFeed extremeCrossRate =
            new CrossRatePriceFeed(USDC_USD_FEED, address(extremeFeed), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);

        // This should work but produce a very large result
        (,,, uint256 updatedAt,) = extremeCrossRate.latestRoundData();
        assertGt(updatedAt, 0);
    }

    /// @notice test overflow protection
    function test_latestRoundData_protectsOverflow() public {
        // Create a scenario that will definitely cause overflow
        // Use a very large number that will overflow when multiplied by the scale factor
        MockV3Aggregator overflowFeed = new MockV3Aggregator(8, type(int256).max);

        CrossRatePriceFeed overflowCrossRate =
            new CrossRatePriceFeed(address(overflowFeed), ETH_USD_FEED, USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);

        // Contract should revert on overflow
        vm.expectRevert();
        overflowCrossRate.latestRoundData();
    }

    /// @notice test getRoundData reverts for any round ID
    function testFuzz_getRoundData_revertsForAnyRoundId(uint80 roundId) public {
        vm.expectRevert(ICrossRatePriceFeed.GetRoundDataNotSupported.selector);
        crossRatePriceFeed.getRoundData(roundId);
    }

    function test_latestRoundData_realValues() public {
        MockV3Aggregator numeratorFeed = new MockV3Aggregator(8, 99987137);
        MockV3Aggregator denominatorFeed = new MockV3Aggregator(8, 450076000000);

        CrossRatePriceFeed crossFeed = new CrossRatePriceFeed(
            address(numeratorFeed), address(denominatorFeed), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT
        );
        (, int256 answer,,,) = crossFeed.latestRoundData();

        int256 expectedAnswer = 22215;

        assertEq(uint256(answer), uint256(expectedAnswer));
    }

    function testFuzz_latestRoundData_realValuesDecimals8(int256 numeratorAnswer, int256 denominatorAnswer) public {
        vm.assume(numeratorAnswer > 100_000 && numeratorAnswer < 100_000_000_000);
        vm.assume(denominatorAnswer > 0 && denominatorAnswer < 400_000_000_000_000);

        MockV3Aggregator numeratorFeed = new MockV3Aggregator(8, numeratorAnswer);
        MockV3Aggregator denominatorFeed = new MockV3Aggregator(8, denominatorAnswer);

        CrossRatePriceFeed crossFeed = new CrossRatePriceFeed(
            address(numeratorFeed), address(denominatorFeed), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT
        );
        (, int256 answer,,,) = crossFeed.latestRoundData();

        int256 expectedAnswer = (numeratorAnswer * 10 ** 8) / denominatorAnswer;

        assertEq(uint256(answer), uint256(expectedAnswer));
    }

    function testFuzz_latestRoundData_realValuesDecimals18(int256 numeratorAnswer, int256 denominatorAnswer) public {
        vm.assume(numeratorAnswer > 1_000_000_000_000_000 && numeratorAnswer < 1_000_000_000_000_000_000_000_000);
        vm.assume(denominatorAnswer > 0 && denominatorAnswer < 4_000_000_000_000_000_000_000_000);

        MockV3Aggregator numeratorFeed = new MockV3Aggregator(18, numeratorAnswer);
        MockV3Aggregator denominatorFeed = new MockV3Aggregator(18, denominatorAnswer);

        CrossRatePriceFeed crossFeed = new CrossRatePriceFeed(
            address(numeratorFeed), address(denominatorFeed), USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT
        );
        (, int256 answer,,,) = crossFeed.latestRoundData();

        int256 expectedAnswer = (numeratorAnswer * 10 ** 18) / denominatorAnswer;

        assertEq(uint256(answer), uint256(expectedAnswer));
    }

    /// @notice test latestRoundData uses numerator feed's round ID
    function test_latestRoundData_usesNumeratorRoundId() public view {
        (uint80 numeratorRoundId,,,,) = usdcUsdFeed.latestRoundData();
        (uint80 crossRoundId,,,,) = crossRatePriceFeed.latestRoundData();
        assertEq(crossRoundId, numeratorRoundId);
    }

    /// @notice test latestRoundData uses numerator feed's answered in round
    function test_latestRoundData_usesNumeratorAnsweredInRound() public view {
        (,,,, uint80 numeratorAnsweredInRound) = usdcUsdFeed.latestRoundData();
        (,,,, uint80 crossAnsweredInRound) = crossRatePriceFeed.latestRoundData();
        assertEq(crossAnsweredInRound, numeratorAnsweredInRound);
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

    /// @notice test latestRoundData uses earlier updated at timestamp
    function test_latestRoundData_usesEarlierUpdatedAt() public view {
        (,,, uint256 numeratorUpdatedAt,) = usdcUsdFeed.latestRoundData();
        (,,, uint256 denominatorUpdatedAt,) = ethUsdFeed.latestRoundData();
        (,,, uint256 crossUpdatedAt,) = crossRatePriceFeed.latestRoundData();

        uint256 expectedUpdatedAt =
            denominatorUpdatedAt < numeratorUpdatedAt ? denominatorUpdatedAt : numeratorUpdatedAt;

        assertEq(crossUpdatedAt, expectedUpdatedAt);
    }

    /// @notice test multiple calls return identical data
    function test_latestRoundData_returnsConsistentData() public view {
        (uint80 roundId1, int256 answer1, uint256 startedAt1, uint256 updatedAt1, uint80 answeredInRound1) =
            crossRatePriceFeed.latestRoundData();
        (uint80 roundId2, int256 answer2, uint256 startedAt2, uint256 updatedAt2, uint80 answeredInRound2) =
            crossRatePriceFeed.latestRoundData();

        assertEq(roundId1, roundId2);
        assertEq(answer1, answer2);
        assertEq(startedAt1, startedAt2);
        assertEq(updatedAt1, updatedAt2);
        assertEq(answeredInRound1, answeredInRound2);
    }

    // ============ METADATA TESTS ============

    /// @notice test version is set
    function test_version_isSet() public view {
        uint256 version = crossRatePriceFeed.version();
        assertEq(version, 1);
    }

    /// @notice test description is set
    function test_description_isSet() public view {
        string memory description = crossRatePriceFeed.description();

        assertGt(bytes(description).length, 0);

        string memory expectedDescription =
            string(abi.encodePacked("(", usdcUsdFeed.description(), ") / (", ethUsdFeed.description(), ")"));

        assertEq(description, expectedDescription);
    }

    /// @notice test started at is before or equal to updated at
    function test_latestRoundData_startedAtBeforeUpdatedAt() public view {
        (,, uint256 crossStartedAt, uint256 crossUpdatedAt,) = crossRatePriceFeed.latestRoundData();
        assertGe(crossUpdatedAt, crossStartedAt);
    }

    /// @notice test cross rate is positive when both feeds are positive
    function test_latestRoundData_positiveWhenFeedsPositive() public view {
        (, int256 numeratorAnswer,,,) = usdcUsdFeed.latestRoundData();
        (, int256 denominatorAnswer,,,) = ethUsdFeed.latestRoundData();
        (, int256 crossAnswer,,,) = crossRatePriceFeed.latestRoundData();

        // Both feeds should be positive
        assertGt(numeratorAnswer, 0);
        assertGt(denominatorAnswer, 0);

        // Cross rate should be positive
        assertGt(crossAnswer, 0);
    }
}
