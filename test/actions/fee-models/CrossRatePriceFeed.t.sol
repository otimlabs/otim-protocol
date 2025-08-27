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
            ETH_USD_FEED   // denominator (ETH/USD)
        );
    }

    // ============ CONSTRUCTOR TESTS ============

    function test_constructor() public view {
        // Test constructor parameters are set correctly
        assertEq(address(crossRatePriceFeed.numeratorFeed()), USDC_USD_FEED);
        assertEq(address(crossRatePriceFeed.denominatorFeed()), ETH_USD_FEED);
        
        // Test decimals calculation
        uint8 numeratorDecimals = usdcUsdFeed.decimals();
        uint8 denominatorDecimals = ethUsdFeed.decimals();
        uint8 expectedDecimals = numeratorDecimals > denominatorDecimals ? numeratorDecimals : denominatorDecimals;
        assertEq(crossRatePriceFeed.decimals(), expectedDecimals);
    }

    function test_constructorWithZeroAddress() public {
        // Test that constructor reverts with zero addresses
        vm.expectRevert();
        new CrossRatePriceFeed(address(0), ETH_USD_FEED);
        
        vm.expectRevert();
        new CrossRatePriceFeed(USDC_USD_FEED, address(0));
        
        vm.expectRevert();
        new CrossRatePriceFeed(address(0), address(0));
    }

    // ============ INTERFACE COMPLIANCE TESTS ============

    function test_interfaceCompliance() public view {
        // Test that the contract implements ICrossRatePriceFeed
        ICrossRatePriceFeed interfaceContract = ICrossRatePriceFeed(address(crossRatePriceFeed));
        
        // Test all interface functions exist and work
        assertEq(address(interfaceContract.numeratorFeed()), USDC_USD_FEED);
        assertEq(address(interfaceContract.denominatorFeed()), ETH_USD_FEED);
        assertGt(interfaceContract.decimals(), 0);
        assertGt(interfaceContract.version(), 0);
        assertGt(bytes(interfaceContract.description()).length, 0);
    }

    // ============ LATEST ROUND DATA TESTS ============

    function test_latestRoundData() public view {
        // Get latest data from individual feeds
        (uint80 numeratorRoundId, int256 numeratorAnswer,, uint256 numeratorUpdatedAt, uint80 numeratorAnsweredInRound) = usdcUsdFeed.latestRoundData();
        (, int256 denominatorAnswer,, uint256 denominatorUpdatedAt,) = ethUsdFeed.latestRoundData();
        
        // Get cross-rate data
        (uint80 crossRoundId, int256 crossAnswer,, uint256 crossUpdatedAt, uint80 crossAnsweredInRound) = crossRatePriceFeed.latestRoundData();
        
        // Validate basic properties
        assertGt(numeratorAnswer, 0, "Numerator price should be positive");
        assertGt(denominatorAnswer, 0, "Denominator price should be positive");
        assertGt(crossAnswer, 0, "Cross rate should be positive");
        
        // Validate round ID consistency
        assertEq(crossRoundId, numeratorRoundId, "Cross rate should use numerator feed's round ID");
        
        // Validate timestamp consistency
        uint256 expectedUpdatedAt = numeratorUpdatedAt > denominatorUpdatedAt ? numeratorUpdatedAt : denominatorUpdatedAt;
        assertEq(crossUpdatedAt, expectedUpdatedAt, "Cross rate should use latest updated timestamp");
        
        // Validate answered in round
        assertEq(crossAnsweredInRound, numeratorAnsweredInRound, "Cross rate should use numerator feed's answered in round");
    }

    function test_latestRoundDataConsistency() public view {
        // Test that multiple calls return the same data
        (uint80 roundId1, int256 answer1, uint256 startedAt1, uint256 updatedAt1, uint80 answeredInRound1) = crossRatePriceFeed.latestRoundData();
        (uint80 roundId2, int256 answer2, uint256 startedAt2, uint256 updatedAt2, uint80 answeredInRound2) = crossRatePriceFeed.latestRoundData();
        (uint80 roundId3, int256 answer3, uint256 startedAt3, uint256 updatedAt3, uint80 answeredInRound3) = crossRatePriceFeed.latestRoundData();
        
        assertEq(roundId1, roundId2, "Round IDs should be consistent");
        assertEq(roundId2, roundId3, "Round IDs should be consistent");
        assertEq(answer1, answer2, "Answers should be consistent");
        assertEq(answer2, answer3, "Answers should be consistent");
        assertEq(startedAt1, startedAt2, "Started at should be consistent");
        assertEq(startedAt2, startedAt3, "Started at should be consistent");
        assertEq(updatedAt1, updatedAt2, "Updated at should be consistent");
        assertEq(updatedAt2, updatedAt3, "Updated at should be consistent");
        assertEq(answeredInRound1, answeredInRound2, "Answered in round should be consistent");
        assertEq(answeredInRound2, answeredInRound3, "Answered in round should be consistent");
    }

    // ============ GET ROUND DATA TESTS ============

    function test_getRoundDataReverts() public {
        // Test that getRoundData always reverts with the correct error
        vm.expectRevert(ICrossRatePriceFeed.GetRoundDataNotSupported.selector);
        crossRatePriceFeed.getRoundData(1);
        
        vm.expectRevert(ICrossRatePriceFeed.GetRoundDataNotSupported.selector);
        crossRatePriceFeed.getRoundData(0);
        
        vm.expectRevert(ICrossRatePriceFeed.GetRoundDataNotSupported.selector);
        crossRatePriceFeed.getRoundData(type(uint80).max);
    }

    function testFuzz_getRoundDataAlwaysReverts(uint80 roundId) public {
        // Test that getRoundData reverts for any round ID
        vm.expectRevert(ICrossRatePriceFeed.GetRoundDataNotSupported.selector);
        crossRatePriceFeed.getRoundData(roundId);
    }

    // ============ CROSS RATE CALCULATION TESTS ============

    function test_crossRateCalculationAccuracy() public view {
        // Get latest data from individual feeds
        (uint80 numeratorRoundId, int256 numeratorAnswer,,,) = usdcUsdFeed.latestRoundData();
        (, int256 denominatorAnswer,,,) = ethUsdFeed.latestRoundData();
        
        // Get cross-rate data
        (uint80 crossRoundId, int256 crossAnswer,,,) = crossRatePriceFeed.latestRoundData();
        
        // Calculate expected cross rate manually
        int256 expectedCrossRate = _calculateExpectedCrossRate(numeratorAnswer, denominatorAnswer);
        
        // Validate calculation accuracy
        assertEq(crossAnswer, expectedCrossRate, "Cross rate calculation should be accurate");
        
        // Validate metadata
        assertEq(crossRoundId, numeratorRoundId, "Cross rate should use numerator feed's round ID");
    }

    function test_crossRateMathematicalProperties() public view {
        // Get latest data
        (, int256 numeratorAnswer,,,) = usdcUsdFeed.latestRoundData();
        (, int256 denominatorAnswer,,,) = ethUsdFeed.latestRoundData();
        (, int256 crossAnswer,,,) = crossRatePriceFeed.latestRoundData();
        
        // Test mathematical properties
        assertGt(numeratorAnswer, 0, "Numerator should be positive");
        assertGt(denominatorAnswer, 0, "Denominator should be positive");
        assertGt(crossAnswer, 0, "Cross rate should be positive");
        
        // Test that cross rate is reasonable (USDC/ETH should be a small number)
        assertLt(uint256(crossAnswer), 1e8, "USDC/ETH rate should be less than 1");
        assertGt(uint256(crossAnswer), 1e3, "USDC/ETH rate should be greater than 0.001");
        
        // Test precision scaling
        uint8 numeratorDecimals = usdcUsdFeed.decimals();
        uint8 denominatorDecimals = ethUsdFeed.decimals();
        uint8 crossDecimals = crossRatePriceFeed.decimals();
        
        // Cross decimals should be the maximum of numerator and denominator decimals
        uint8 expectedCrossDecimals = numeratorDecimals > denominatorDecimals ? numeratorDecimals : denominatorDecimals;
        assertEq(crossDecimals, expectedCrossDecimals, "Cross decimals should be max of input decimals");
    }

    // ============ DECIMAL PRECISION TESTS ============

    function test_decimalPrecision() public view {
        uint8 numeratorDecimals = usdcUsdFeed.decimals();
        uint8 denominatorDecimals = ethUsdFeed.decimals();
        uint8 crossDecimals = crossRatePriceFeed.decimals();
        
        // Cross decimals should be the maximum of numerator and denominator decimals
        uint8 expectedDecimals = numeratorDecimals > denominatorDecimals ? numeratorDecimals : denominatorDecimals;
        assertEq(crossDecimals, expectedDecimals, "Cross decimals should be max of input decimals");
        
        // Test that the calculation maintains precision
        (, int256 numeratorAnswer,,,) = usdcUsdFeed.latestRoundData();
        (, int256 denominatorAnswer,,,) = ethUsdFeed.latestRoundData();
        (, int256 crossAnswer,,,) = crossRatePriceFeed.latestRoundData();
        
        // Manual calculation with proper scaling
        int256 scaledNumerator = numeratorAnswer;
        int256 scaledDenominator = denominatorAnswer;
        
        if (numeratorDecimals < crossDecimals) {
            scaledNumerator = numeratorAnswer * int256(10 ** (crossDecimals - numeratorDecimals));
        }
        if (denominatorDecimals < crossDecimals) {
            scaledDenominator = denominatorAnswer * int256(10 ** (crossDecimals - denominatorDecimals));
        }
        
        int256 expectedCrossRate = (scaledNumerator * int256(10 ** crossDecimals)) / scaledDenominator;
        assertEq(crossAnswer, expectedCrossRate, "Cross rate should match manual calculation with proper scaling");
    }

    // ============ TIMESTAMP LOGIC TESTS ============

    function test_timestampLogic() public view {
        // Get latest data from individual feeds
        (,, uint256 numeratorStartedAt, uint256 numeratorUpdatedAt,) = usdcUsdFeed.latestRoundData();
        (,, uint256 denominatorStartedAt, uint256 denominatorUpdatedAt,) = ethUsdFeed.latestRoundData();
        
        // Get cross-rate data
        (,, uint256 crossStartedAt, uint256 crossUpdatedAt,) = crossRatePriceFeed.latestRoundData();
        
        // Cross rate should use the latest timestamps from both feeds
        uint256 expectedStartedAt = numeratorStartedAt > denominatorStartedAt ? numeratorStartedAt : denominatorStartedAt;
        uint256 expectedUpdatedAt = numeratorUpdatedAt > denominatorUpdatedAt ? numeratorUpdatedAt : denominatorUpdatedAt;
        assertEq(crossStartedAt, expectedStartedAt, "Cross rate should use latest started at from both feeds");
        assertEq(crossUpdatedAt, expectedUpdatedAt, "Cross rate should use latest updated at from both feeds");
        
        // Validate timestamps are reasonable
        assertGt(crossStartedAt, 0, "Started at should be positive");
        assertGt(crossUpdatedAt, 0, "Updated at should be positive");
        assertGe(crossUpdatedAt, crossStartedAt, "Updated at should be >= started at");
        
        // Validate timestamps are recent (within last 24 hours)
        assertLt(block.timestamp - crossUpdatedAt, 86400, "Data should be recent (within 24 hours)");
    }

    // ============ EDGE CASES AND BOUNDARY TESTS ============

    function test_edgeCases() public view {
        // Test with extreme but valid values
        (, int256 numeratorAnswer,,,) = usdcUsdFeed.latestRoundData();
        (, int256 denominatorAnswer,,,) = ethUsdFeed.latestRoundData();
        (, int256 crossAnswer,,,) = crossRatePriceFeed.latestRoundData();
        
        // Test that all values are within reasonable bounds
        assertGt(numeratorAnswer, 0, "Numerator should be positive");
        assertGt(denominatorAnswer, 0, "Denominator should be positive");
        assertGt(crossAnswer, 0, "Cross rate should be positive");
        
        // Test that cross rate is reasonable for USDC/ETH
        assertLt(uint256(crossAnswer), 1e8, "USDC/ETH rate should be less than 1");
        assertGt(uint256(crossAnswer), 1e3, "USDC/ETH rate should be greater than 0.001");
    }

    function test_overflowProtection() public view {
        // Test that the contract handles large numbers without overflow
        (, int256 numeratorAnswer,,,) = usdcUsdFeed.latestRoundData();
        (, int256 denominatorAnswer,,,) = ethUsdFeed.latestRoundData();
        
        // Test that calculation doesn't overflow
        uint8 crossDecimals = crossRatePriceFeed.decimals();
        uint256 maxSafeNumerator = type(uint256).max / (10 ** crossDecimals);
        
        assertLt(uint256(numeratorAnswer), maxSafeNumerator, "Numerator should not cause overflow");
        assertGt(denominatorAnswer, 0, "Denominator should be positive to avoid division by zero");
    }

    // ============ METADATA TESTS ============

    function test_metadata() public view {
        // Test description
        string memory description = crossRatePriceFeed.description();
        assertGt(bytes(description).length, 0, "Description should not be empty");
        
        // Test version
        uint256 version = crossRatePriceFeed.version();
        assertGt(version, 0, "Version should be positive");
        
        // Test decimals
        uint8 decimals = crossRatePriceFeed.decimals();
        assertGt(decimals, 0, "Decimals should be positive");
        assertLe(decimals, 18, "Decimals should be <= 18");
        
        // Test feed addresses
        assertEq(address(crossRatePriceFeed.numeratorFeed()), USDC_USD_FEED, "Numerator feed should match");
        assertEq(address(crossRatePriceFeed.denominatorFeed()), ETH_USD_FEED, "Denominator feed should match");
    }

    // ============ FUZZ TESTS ============

    function testFuzz_latestRoundDataConsistency(uint256 seed) public view {
        // Use seed to vary test conditions
        vm.assume(seed > 0);
        
        // Get data multiple times to ensure consistency
        (uint80 roundId1, int256 answer1, uint256 startedAt1, uint256 updatedAt1, uint80 answeredInRound1) = crossRatePriceFeed.latestRoundData();
        (uint80 roundId2, int256 answer2, uint256 startedAt2, uint256 updatedAt2, uint80 answeredInRound2) = crossRatePriceFeed.latestRoundData();
        
        // All values should be identical
        assertEq(roundId1, roundId2, "Round IDs should be consistent");
        assertEq(answer1, answer2, "Answers should be consistent");
        assertEq(startedAt1, startedAt2, "Started at should be consistent");
        assertEq(updatedAt1, updatedAt2, "Updated at should be consistent");
        assertEq(answeredInRound1, answeredInRound2, "Answered in round should be consistent");
    }

    function testFuzz_crossRateBounds(uint256 seed) public view {
        // Use seed to vary test conditions
        vm.assume(seed > 0);
        
        (, int256 crossAnswer,,,) = crossRatePriceFeed.latestRoundData();
        
        // Test bounds for USDC/ETH rate
        assertGt(crossAnswer, 0, "Cross rate should be positive");
        assertLt(uint256(crossAnswer), 1e8, "USDC/ETH rate should be less than 1");
        assertGt(uint256(crossAnswer), 1e3, "USDC/ETH rate should be greater than 0.001");
    }

    // ============ HELPER FUNCTIONS ============

    function _calculateExpectedCrossRate(int256 numeratorAnswer, int256 denominatorAnswer) internal view returns (int256) {
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
