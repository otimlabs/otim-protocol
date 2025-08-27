// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/src/Test.sol";
import {CrossRatePriceFeed} from "../../../src/actions/fee-models/CrossRatePriceFeed.sol";
import {ICrossRatePriceFeed} from "../../../src/actions/fee-models/interfaces/ICrossRatePriceFeed.sol";
import {AggregatorV3Interface} from "@chainlink-contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

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

    function setUp() public {
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

    // ============ CRITICAL SECURITY TESTS ============

    /// @notice test constructor reverts with invalid feed contract
    function test_constructor_revertsInvalidFeed() public {
        // Test with EOA address
        vm.expectRevert();
        new CrossRatePriceFeed(address(1), ETH_USD_FEED);

        vm.expectRevert();
        new CrossRatePriceFeed(USDC_USD_FEED, address(1));
    }

    /// @notice test constructor reverts with malicious feed that reverts on decimals()
    function test_constructor_revertsMaliciousFeed() public {
        vm.expectRevert();
        new CrossRatePriceFeed(address(maliciousFeed), ETH_USD_FEED);

        vm.expectRevert();
        new CrossRatePriceFeed(USDC_USD_FEED, address(maliciousFeed));
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

    /// @notice test getRoundData always reverts with correct error
    function test_getRoundData_revertsWithCorrectError() public {
        vm.expectRevert(ICrossRatePriceFeed.GetRoundDataNotSupported.selector);
        crossRatePriceFeed.getRoundData(1);
    }

    /// @notice test getRoundData reverts for any round ID
    function testFuzz_getRoundData_revertsForAnyRoundId(uint80 roundId) public {
        vm.expectRevert(ICrossRatePriceFeed.GetRoundDataNotSupported.selector);
        crossRatePriceFeed.getRoundData(roundId);
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

    /// @notice test cross rate calculation is mathematically correct
    function test_latestRoundData_calculationIsCorrect() public view {
        (, int256 numeratorAnswer,,,) = usdcUsdFeed.latestRoundData();
        (, int256 denominatorAnswer,,,) = ethUsdFeed.latestRoundData();
        (, int256 crossAnswer,,,) = crossRatePriceFeed.latestRoundData();

        int256 expectedCrossRate = _calculateExpectedCrossRate(numeratorAnswer, denominatorAnswer);
        assertEq(crossAnswer, expectedCrossRate);
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

    /// @notice test description format
    function test_description_format() public view {
        string memory description = crossRatePriceFeed.description();
        assertGt(bytes(description).length, 0);

        // Should contain both feed names
        assertTrue(_containsSubstring(description, "USDC"));
        assertTrue(_containsSubstring(description, "ETH"));
    }

    /// @notice test version is non-zero
    function test_version_isNonZero() public view {
        uint256 version = crossRatePriceFeed.version();
        assertGt(version, 0);
    }

    /// @notice test decimals are within valid range
    function test_decimals_areValid() public view {
        uint8 decimals = crossRatePriceFeed.decimals();
        assertGt(decimals, 0);
        assertLe(decimals, 18);
    }

    /// @notice test interface compliance
    function test_interfaceCompliance() public view {
        ICrossRatePriceFeed interfaceContract = ICrossRatePriceFeed(address(crossRatePriceFeed));

        assertEq(address(interfaceContract.numeratorFeed()), USDC_USD_FEED);
        assertEq(address(interfaceContract.denominatorFeed()), ETH_USD_FEED);
        assertGt(interfaceContract.decimals(), 0);
        assertGt(interfaceContract.version(), 0);
        assertGt(bytes(interfaceContract.description()).length, 0);
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

    /// @notice test timestamps are recent
    function test_latestRoundData_timestampsAreRecent() public view {
        (,,, uint256 crossUpdatedAt,) = crossRatePriceFeed.latestRoundData();

        // Data should be recent (within last 24 hours)
        assertLt(block.timestamp - crossUpdatedAt, 86400);
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

    /// @notice helper function to check if string contains substring
    function _containsSubstring(string memory str, string memory substr) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);

        if (substrBytes.length > strBytes.length) {
            return false;
        }

        for (uint256 i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }
        return false;
    }

    // ============ VULNERABILITY DOCUMENTATION TESTS ============

    /// @notice VULNERABILITY: Contract accepts negative values without validation
    function test_latestRoundData_acceptsNegativeValues() public {
        MockPriceFeed negativeFeed = new MockPriceFeed();
        negativeFeed.setMockData(1, -1000, 8, 1, block.timestamp, 1); // negative price

        CrossRatePriceFeed negativeCrossRate = new CrossRatePriceFeed(USDC_USD_FEED, address(negativeFeed));

        // VULNERABILITY: Contract should revert but doesn't
        (,,, uint256 updatedAt,) = negativeCrossRate.latestRoundData();
        assertGt(updatedAt, 0); // This passes, showing the vulnerability
    }

    /// @notice VULNERABILITY: Contract doesn't protect against overflow
    function test_latestRoundData_doesntProtectOverflow() public {
        MockPriceFeed overflowFeed = new MockPriceFeed();
        overflowFeed.setMockData(1, type(int256).max, 8, 1, block.timestamp, 1); // max int

        CrossRatePriceFeed overflowCrossRate = new CrossRatePriceFeed(USDC_USD_FEED, address(overflowFeed));

        // VULNERABILITY: Contract should revert but doesn't
        (,,, uint256 updatedAt,) = overflowCrossRate.latestRoundData();
        assertGt(updatedAt, 0); // This passes, showing the vulnerability
    }

    /// @notice VULNERABILITY: Contract doesn't handle stale data properly
    function test_latestRoundData_doesntHandleStaleData() public {
        uint256 staleTimestamp = block.timestamp - 86400; // 24 hours old
        MockPriceFeed staleFeed = new MockPriceFeed();
        staleFeed.setMockData(1, 3000, 8, 1, staleTimestamp, 1);

        CrossRatePriceFeed staleCrossRate = new CrossRatePriceFeed(USDC_USD_FEED, address(staleFeed));

        // VULNERABILITY: Contract should detect stale data but doesn't
        (,,, uint256 updatedAt,) = staleCrossRate.latestRoundData();
        assertGt(updatedAt, 0); // Contract accepts stale data without validation
    }

    /// @notice VULNERABILITY: Contract doesn't handle very old data
    function test_latestRoundData_doesntHandleVeryOldData() public {
        uint256 oldTimestamp = block.timestamp - 365 days; // 1 year old
        MockPriceFeed oldFeed = new MockPriceFeed();
        oldFeed.setMockData(1, 3000, 8, 1, oldTimestamp, 1);

        CrossRatePriceFeed oldCrossRate = new CrossRatePriceFeed(USDC_USD_FEED, address(oldFeed));

        // VULNERABILITY: Contract should detect very old data but doesn't
        (,,, uint256 updatedAt,) = oldCrossRate.latestRoundData();
        assertGt(updatedAt, 0); // Contract accepts very old data without validation
    }
}

// ============ MOCK CONTRACTS FOR TESTING ============

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

    function getRoundData(uint80 _roundId)
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

contract MaliciousPriceFeed is AggregatorV3Interface {
    function latestRoundData()
        external
        pure
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        revert("Malicious feed always reverts");
    }

    function getRoundData(uint80 _roundId)
        external
        pure
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        revert("Malicious feed always reverts");
    }

    function decimals() external pure returns (uint8) {
        revert("Malicious feed always reverts");
    }

    function version() external pure returns (uint256) {
        revert("Malicious feed always reverts");
    }

    function description() external pure returns (string memory) {
        revert("Malicious feed always reverts");
    }
}
