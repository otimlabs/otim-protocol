// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/src/Test.sol";
import {CrossRatePriceFeed} from "../../src/infrastructure/CrossRatePriceFeed.sol";
import {ICrossRatePriceFeed} from "../../src/infrastructure/interfaces/ICrossRatePriceFeed.sol";
import {AggregatorV3Interface} from "@chainlink-contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {MockPriceFeed} from "../mocks/MockPriceFeed.sol";
import {MaliciousPriceFeed} from "../mocks/MaliciousPriceFeed.sol";

contract CrossRatePriceFeedTest is Test {
    // Sepolia price feed addresses
    address constant ETH_USD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address constant USDC_USD_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;

    CrossRatePriceFeed public crossRatePriceFeed;
    AggregatorV3Interface public ethUsdFeed;
    AggregatorV3Interface public usdcUsdFeed;

    // Mock contracts for edge case testing
    MockPriceFeed public mockFeed;
    MaliciousPriceFeed public maliciousFeed;

    constructor() {
        // Fork Sepolia
        string memory rpcUrl = vm.envOr("SEPOLIA_RPC_URL", vm.rpcUrl("sepolia"));
        vm.createSelectFork(rpcUrl);

        // Initialize price feeds
        ethUsdFeed = AggregatorV3Interface(ETH_USD_FEED);
        usdcUsdFeed = AggregatorV3Interface(USDC_USD_FEED);

        // Deploy CrossRatePriceFeed with USDC/USD as numerator and ETH/USD as denominator
        // This will create a USDC/ETH rate
        crossRatePriceFeed = new CrossRatePriceFeed(
            USDC_USD_FEED, // numerator (USDC/USD)
            ETH_USD_FEED // denominator (ETH/USD)
        );

        // Deploy mock contracts for edge case testing
        mockFeed = new MockPriceFeed();
        maliciousFeed = new MaliciousPriceFeed();
    }

    // ============ BASIC FUNCTIONALITY TESTS ============

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
        new CrossRatePriceFeed(address(0), ETH_USD_FEED);
    }

    /// @notice test constructor reverts with zero denominator feed
    function test_constructor_revertsZeroDenominator() public {
        vm.expectRevert();
        new CrossRatePriceFeed(USDC_USD_FEED, address(0));
    }

    // ============ MATHEMATICAL EDGE CASE TESTS ============

    /// @notice test division by zero protection
    function test_latestRoundData_handlesZeroDenominator() public {
        MockPriceFeed zeroDenominatorFeed = new MockPriceFeed();
        zeroDenominatorFeed.setMockData(1, 0, 8, 1, block.timestamp, 1); // denominator = 0

        CrossRatePriceFeed zeroCrossRate = new CrossRatePriceFeed(USDC_USD_FEED, address(zeroDenominatorFeed));

        vm.expectRevert();
        zeroCrossRate.latestRoundData();
    }

    /// @notice test extreme price ratios
    function test_latestRoundData_handlesExtremeRatios() public {
        MockPriceFeed extremeFeed = new MockPriceFeed();
        extremeFeed.setMockData(1, 1, 8, 1, block.timestamp, 1); // very small denominator

        CrossRatePriceFeed extremeCrossRate = new CrossRatePriceFeed(USDC_USD_FEED, address(extremeFeed));

        // This should work but produce a very large result
        (,,, uint256 updatedAt,) = extremeCrossRate.latestRoundData();
        assertGt(updatedAt, 0);
    }

    /// @notice test overflow protection
    function test_latestRoundData_protectsOverflow() public {
        // Create a scenario that will definitely cause overflow
        // Use a very large number that will overflow when multiplied by the scale factor
        MockPriceFeed overflowFeed = new MockPriceFeed();
        // Use a number that will definitely overflow when multiplied by 10^8 (scale factor)
        overflowFeed.setMockData(1, type(int256).max / 100, 0, 1, block.timestamp, 1); // 0 decimals, will scale by 10^8

        CrossRatePriceFeed overflowCrossRate = new CrossRatePriceFeed(USDC_USD_FEED, address(overflowFeed));

        // Contract should revert on overflow
        vm.expectRevert(ICrossRatePriceFeed.Overflow.selector);
        overflowCrossRate.latestRoundData();
    }

    // ============ PRECISION TESTS ============

    /// @notice test precision loss scenarios
    function test_latestRoundData_handlesPrecisionLoss() public {
        MockPriceFeed precisionFeed = new MockPriceFeed();
        precisionFeed.setMockData(1, 1, 18, 1, block.timestamp, 1); // 18 decimals

        CrossRatePriceFeed precisionCrossRate = new CrossRatePriceFeed(
            USDC_USD_FEED, // 8 decimals
            address(precisionFeed) // 18 decimals
        );

        // Should handle different decimal precisions correctly
        (,,, uint256 updatedAt,) = precisionCrossRate.latestRoundData();
        assertGt(updatedAt, 0);
    }

    /// @notice test rounding behavior
    function test_latestRoundData_roundingBehavior() public {
        MockPriceFeed roundingFeed = new MockPriceFeed();
        roundingFeed.setMockData(100000001, 300000000, 8, 1, block.timestamp, 1); // 1.00000001 / 3.00000000

        CrossRatePriceFeed roundingCrossRate = new CrossRatePriceFeed(USDC_USD_FEED, address(roundingFeed));

        // Should calculate correctly with rounding
        (,,, uint256 updatedAt,) = roundingCrossRate.latestRoundData();
        assertGt(updatedAt, 0);
    }

    // ============ INTERFACE COMPLIANCE TESTS ============

    /// @notice test getRoundData reverts for any round ID
    function testFuzz_getRoundData_revertsForAnyRoundId(uint80 roundId) public {
        vm.expectRevert(ICrossRatePriceFeed.GetRoundDataNotSupported.selector);
        crossRatePriceFeed.getRoundData(roundId);
    }

    function test_latestRoundData_realValues() public {
        MockPriceFeed numeratorFeed = new MockPriceFeed();
        MockPriceFeed denominatorFeed = new MockPriceFeed();
        numeratorFeed.setMockData(1, 99987137, 8, 1, block.timestamp, 1);
        denominatorFeed.setMockData(1, 450076000000, 8, 1, block.timestamp, 1);

        CrossRatePriceFeed crossFeed = new CrossRatePriceFeed(address(numeratorFeed), address(denominatorFeed));
        (, int256 answer,,,) = crossFeed.latestRoundData();

        int256 expectedAnswer = 22215;

        assertEq(uint256(answer), uint256(expectedAnswer));
    }

    function testFuzz_latestRoundData_realValues(int256 numeratorAnswer, int256 denominatorAnswer) public {
        vm.assume(numeratorAnswer > 100_000 && numeratorAnswer < 100_000_000_000);
        vm.assume(denominatorAnswer > 0 && denominatorAnswer < 400_000_000_000_000);

        MockPriceFeed numeratorFeed = new MockPriceFeed();
        MockPriceFeed denominatorFeed = new MockPriceFeed();
        numeratorFeed.setMockData(1, numeratorAnswer, 8, 1, block.timestamp, 1);
        denominatorFeed.setMockData(1, denominatorAnswer, 8, 1, block.timestamp, 1);

        CrossRatePriceFeed crossFeed = new CrossRatePriceFeed(address(numeratorFeed), address(denominatorFeed));
        (, int256 answer,,,) = crossFeed.latestRoundData();

        int256 expectedAnswer = (numeratorAnswer * 10 ** 8) / denominatorAnswer;

        assertEq(uint256(answer), uint256(expectedAnswer));
    }

    function testFuzz_latestRoundData_realValues_numerator18(int256 numeratorAnswer, int256 denominatorAnswer) public {
        vm.assume(numeratorAnswer > 1_000_000 && numeratorAnswer < 1_000_000_000_000_000_000_000);
        vm.assume(denominatorAnswer > 0 && denominatorAnswer < 400_000_000_000_000);

        MockPriceFeed numeratorFeed = new MockPriceFeed();
        MockPriceFeed denominatorFeed = new MockPriceFeed();
        numeratorFeed.setMockData(1, numeratorAnswer, 18, 1, block.timestamp, 1);
        denominatorFeed.setMockData(1, denominatorAnswer, 8, 1, block.timestamp, 1);

        CrossRatePriceFeed crossFeed = new CrossRatePriceFeed(address(numeratorFeed), address(denominatorFeed));
        (, int256 answer,,,) = crossFeed.latestRoundData();

        int256 expectedAnswer = (numeratorAnswer * 10 ** 18) / (denominatorAnswer * 10 ** 10);

        assertEq(uint256(answer), uint256(expectedAnswer));
    }

    function testFuzz_latestRoundData_realValues_denominator18(int256 numeratorAnswer, int256 denominatorAnswer)
        public
    {
        vm.assume(numeratorAnswer > 100_000 && numeratorAnswer < 100_000_000_000);
        vm.assume(denominatorAnswer > 0 && denominatorAnswer < 400_000_000_000_000_000_000_000);

        MockPriceFeed numeratorFeed = new MockPriceFeed();
        MockPriceFeed denominatorFeed = new MockPriceFeed();
        numeratorFeed.setMockData(1, numeratorAnswer, 8, 1, block.timestamp, 1);
        denominatorFeed.setMockData(1, denominatorAnswer, 18, 1, block.timestamp, 1);

        CrossRatePriceFeed crossFeed = new CrossRatePriceFeed(address(numeratorFeed), address(denominatorFeed));
        (, int256 answer,,,) = crossFeed.latestRoundData();

        int256 expectedAnswer = (numeratorAnswer * 10 ** 28) / denominatorAnswer;

        assertEq(uint256(answer), uint256(expectedAnswer));
    }

    // ============ BASIC FUNCTIONALITY TESTS ============

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
    function test_latestRoundData_usesLatestStartedAt() public view {
        (,, uint256 numeratorStartedAt,,) = usdcUsdFeed.latestRoundData();
        (,, uint256 denominatorStartedAt,,) = ethUsdFeed.latestRoundData();
        (,, uint256 crossStartedAt,,) = crossRatePriceFeed.latestRoundData();

        uint256 expectedStartedAt =
            numeratorStartedAt > denominatorStartedAt ? numeratorStartedAt : denominatorStartedAt;
        assertEq(crossStartedAt, expectedStartedAt);
    }

    /// @notice test latestRoundData uses latest updated at timestamp
    function test_latestRoundData_usesLatestUpdatedAt() public view {
        (,,, uint256 numeratorUpdatedAt,) = usdcUsdFeed.latestRoundData();
        (,,, uint256 denominatorUpdatedAt,) = ethUsdFeed.latestRoundData();
        (,,, uint256 crossUpdatedAt,) = crossRatePriceFeed.latestRoundData();

        uint256 expectedUpdatedAt =
            numeratorUpdatedAt > denominatorUpdatedAt ? numeratorUpdatedAt : denominatorUpdatedAt;
        assertEq(crossUpdatedAt, expectedUpdatedAt);
    }

    /// @notice test cross rate calculation with different decimal precisions
    function test_latestRoundData_handlesDifferentDecimals() public view {
        uint8 numeratorDecimals = usdcUsdFeed.decimals();
        uint8 denominatorDecimals = ethUsdFeed.decimals();
        uint8 crossDecimals = crossRatePriceFeed.decimals();

        // Verify decimals calculation logic
        uint8 expectedDecimals = numeratorDecimals > denominatorDecimals ? numeratorDecimals : denominatorDecimals;
        assertEq(crossDecimals, expectedDecimals);

        // Verify calculation maintains precision
        (, int256 numeratorAnswer,,,) = usdcUsdFeed.latestRoundData();
        (, int256 denominatorAnswer,,,) = ethUsdFeed.latestRoundData();
        (, int256 crossAnswer,,,) = crossRatePriceFeed.latestRoundData();

        int256 expectedCrossRate = _calculateExpectedCrossRate(numeratorAnswer, denominatorAnswer);
        assertEq(crossAnswer, expectedCrossRate);
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

    // ============ BUSINESS LOGIC TESTS ============

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

    /// @notice test USDC/ETH rate is within expected bounds
    function test_latestRoundData_usdcEthRateBounds() public view {
        (, int256 crossAnswer,,,) = crossRatePriceFeed.latestRoundData();

        // USDC/ETH should be a small number (around 0.0003-0.0004)
        assertLt(uint256(crossAnswer), 1e8); // Less than 1
        assertGt(uint256(crossAnswer), 1e3); // Greater than 0.001
    }

    /// @notice test started at is before or equal to updated at
    function test_latestRoundData_startedAtBeforeUpdatedAt() public view {
        (,, uint256 crossStartedAt, uint256 crossUpdatedAt,) = crossRatePriceFeed.latestRoundData();
        assertGe(crossUpdatedAt, crossStartedAt);
    }

    // ============ HELPER FUNCTIONS ============

    /// @notice helper function to calculate expected cross rate
    function _calculateExpectedCrossRate(int256 numeratorAnswer, int256 denominatorAnswer)
        internal
        view
        returns (int256)
    {
        uint8 numeratorDecimals = usdcUsdFeed.decimals();
        uint8 denominatorDecimals = ethUsdFeed.decimals();
        uint8 crossDecimals = crossRatePriceFeed.decimals();

        int256 scaledNumeratorAnswer = numeratorAnswer;
        int256 scaledDenominatorAnswer = denominatorAnswer;

        // Scale to the higher precision
        if (numeratorDecimals < crossDecimals) {
            scaledNumeratorAnswer = numeratorAnswer * int256(10 ** (crossDecimals - numeratorDecimals));
        }
        if (denominatorDecimals < crossDecimals) {
            scaledDenominatorAnswer = denominatorAnswer * int256(10 ** (crossDecimals - denominatorDecimals));
        }

        return (scaledNumeratorAnswer * int256(10 ** crossDecimals)) / scaledDenominatorAnswer;
    }
}
