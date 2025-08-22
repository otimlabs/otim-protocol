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

    // Test data
    uint80 public latestRoundId;
    uint256 public ethUsdUpdatedAt;
    uint256 public usdcUsdUpdatedAt;

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

        // Get latest data from both feeds
        (,,, ethUsdUpdatedAt,) = ethUsdFeed.latestRoundData();
        (,,, usdcUsdUpdatedAt,) = usdcUsdFeed.latestRoundData();

        // Get the latest round ID from ETH/USD feed
        (latestRoundId,,,,) = ethUsdFeed.latestRoundData();
    }

    /// @notice test cross-rate calculation accuracy
    function test_crossRateCalculationAccuracy() public {
        (, int256 crossRate,,,) = crossRatePriceFeed.latestRoundData();

        (, int256 usdcUsdPrice,,,) = usdcUsdFeed.latestRoundData();
        (, int256 ethUsdPrice,,,) = ethUsdFeed.latestRoundData();

        assertGt(usdcUsdPrice, 0);
        assertGt(ethUsdPrice, 0);

        uint8 usdcDecimals = usdcUsdFeed.decimals();
        uint8 ethDecimals = ethUsdFeed.decimals();
        uint8 crossDecimals = crossRatePriceFeed.decimals();

        int256 scaledUsdcUsd = usdcUsdPrice;
        int256 scaledEthUsd = ethUsdPrice;

        if (usdcDecimals < crossDecimals) {
            scaledUsdcUsd = usdcUsdPrice * int256(10 ** (crossDecimals - usdcDecimals));
        }
        if (ethDecimals < crossDecimals) {
            scaledEthUsd = ethUsdPrice * int256(10 ** (crossDecimals - ethDecimals));
        }

        int256 expectedCrossRate = (scaledUsdcUsd * int256(10 ** crossDecimals)) / scaledEthUsd;

        assertEq(crossRate, expectedCrossRate);
        assertGt(crossRate, 0);
    }

    /// @notice test cross-rate consistency
    function test_crossRateConsistency() public {
        (, int256 crossRate1,,,) = crossRatePriceFeed.latestRoundData();
        (, int256 crossRate2,,,) = crossRatePriceFeed.latestRoundData();
        (, int256 crossRate3,,,) = crossRatePriceFeed.latestRoundData();

        assertEq(crossRate1, crossRate2);
        assertEq(crossRate2, crossRate3);
        assertEq(crossRate1, crossRate3);
    }

    /// @notice test cross-rate different rounds
    function test_crossRateDifferentRounds() public {
        // Get the latest cross-rate for comparison
        (, int256 latestCrossRate,,,) = crossRatePriceFeed.latestRoundData();
        assertGt(latestCrossRate, 0);

        // Test that getRoundData returns the same value as latestRoundData for the latest round
        try crossRatePriceFeed.getRoundData(latestRoundId) returns (
            uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound
        ) {
            if (answer > 0) {
                assertEq(answer, latestCrossRate);
                assertEq(roundId, latestRoundId);
            }
        } catch {
            // It's okay if getRoundData reverts for specific round IDs
        }

        // Test that the cross-rate is consistent between latestRoundData calls
        (, int256 crossRate1,,,) = crossRatePriceFeed.latestRoundData();
        (, int256 crossRate2,,,) = crossRatePriceFeed.latestRoundData();

        assertEq(crossRate1, latestCrossRate);
        assertEq(crossRate2, latestCrossRate);
        assertEq(crossRate1, crossRate2);
    }

    /// @notice test cross-rate extreme prices
    function test_crossRateExtremePrices() public {
        (, int256 usdcUsdPrice,,,) = usdcUsdFeed.latestRoundData();
        (, int256 ethUsdPrice,,,) = ethUsdFeed.latestRoundData();
        (, int256 crossRate,,,) = crossRatePriceFeed.latestRoundData();

        int256 expectedRate = (usdcUsdPrice * int256(10 ** 8)) / ethUsdPrice;

        uint256 percentageDiff;
        if (expectedRate > 0) {
            percentageDiff = uint256(abs(crossRate - expectedRate) * 10000) / uint256(expectedRate);
        }

        assertLt(percentageDiff, 500);
    }

    /// @notice test cross-rate decimal precision
    function test_crossRateDecimalPrecision() public {
        uint8 usdcUsdDecimals = usdcUsdFeed.decimals();
        uint8 ethUsdDecimals = ethUsdFeed.decimals();
        uint8 crossRateDecimals = crossRatePriceFeed.decimals();

        uint8 expectedDecimals = usdcUsdDecimals > ethUsdDecimals ? usdcUsdDecimals : ethUsdDecimals;
        assertEq(crossRateDecimals, expectedDecimals);

        (, int256 crossRate,,,) = crossRatePriceFeed.latestRoundData();
        (, int256 usdcUsdPrice,,,) = usdcUsdFeed.latestRoundData();
        (, int256 ethUsdPrice,,,) = ethUsdFeed.latestRoundData();

        int256 scaledUsdcUsd = usdcUsdPrice;
        int256 scaledEthUsd = ethUsdPrice;

        if (usdcUsdDecimals < crossRateDecimals) {
            scaledUsdcUsd = usdcUsdPrice * int256(10 ** (crossRateDecimals - usdcUsdDecimals));
        }
        if (ethUsdDecimals < crossRateDecimals) {
            scaledEthUsd = ethUsdPrice * int256(10 ** (crossRateDecimals - ethUsdDecimals));
        }

        int256 manualCrossRate = (scaledUsdcUsd * int256(10 ** crossRateDecimals)) / scaledEthUsd;

        uint256 tolerance = uint256(manualCrossRate) / 1000;
        assertApproxEqAbs(uint256(crossRate), uint256(manualCrossRate), tolerance);
    }

    /// @notice test cross-rate timestamp logic
    function test_crossRateTimestampLogic() public {
        (, int256 crossRate, uint256 crossStartedAt, uint256 crossUpdatedAt,) = crossRatePriceFeed.latestRoundData();
        (,, uint256 usdcStartedAt, uint256 usdcUpdatedAt,) = usdcUsdFeed.latestRoundData();
        (,, uint256 ethStartedAt, uint256 ethUpdatedAt,) = ethUsdFeed.latestRoundData();

        uint256 expectedUpdatedAt = usdcUpdatedAt > ethUpdatedAt ? usdcUpdatedAt : ethUpdatedAt;
        uint256 expectedStartedAt = usdcStartedAt > ethStartedAt ? usdcStartedAt : ethStartedAt;

        assertEq(crossUpdatedAt, expectedUpdatedAt);
        assertEq(crossStartedAt, expectedStartedAt);

        assertLt(block.timestamp - crossUpdatedAt, 86400);
        assertGt(crossRate, 0);
    }

    /// @notice test cross-rate mathematical edge cases
    function test_crossRateMathematicalEdgeCases() public {
        (, int256 usdcPrice,,,) = usdcUsdFeed.latestRoundData();
        (, int256 ethPrice,,,) = ethUsdFeed.latestRoundData();
        (, int256 crossRate,,,) = crossRatePriceFeed.latestRoundData();

        assertGt(ethPrice, 0);
        assertGt(usdcPrice, 0);

        uint8 decimals = crossRatePriceFeed.decimals();

        uint256 maxSafeValue = type(uint256).max / (10 ** decimals);
        assertLt(uint256(usdcPrice), maxSafeValue);

        int256 roughEstimate = (usdcPrice * int256(10 ** decimals)) / ethPrice;
        uint256 tolerance = uint256(roughEstimate) / 10;
        assertApproxEqAbs(uint256(crossRate), uint256(roughEstimate), tolerance);
    }

    /// @notice test cross-rate invalid rounds
    function test_crossRateInvalidRounds() public {
        uint80 invalidRoundId = 999999;

        try crossRatePriceFeed.getRoundData(invalidRoundId) returns (
            uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound
        ) {
            assertEq(roundId, 0);
            assertEq(answer, 0);
            assertEq(startedAt, 0);
            assertEq(updatedAt, 0);
            assertEq(answeredInRound, 0);
        } catch {}

        try crossRatePriceFeed.getRoundData(0) returns (
            uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound
        ) {
            assertEq(roundId, 0);
            assertEq(answer, 0);
        } catch {}
    }

    /// @notice test cross-rate precision loss
    function test_crossRatePrecisionLoss() public {
        uint8 usdcDecimals = usdcUsdFeed.decimals();
        uint8 ethDecimals = ethUsdFeed.decimals();
        uint8 crossDecimals = crossRatePriceFeed.decimals();

        (, int256 usdcPrice,,,) = usdcUsdFeed.latestRoundData();
        (, int256 ethPrice,,,) = ethUsdFeed.latestRoundData();
        (, int256 crossRate,,,) = crossRatePriceFeed.latestRoundData();

        int256 scaledUsdcPrice = usdcPrice;
        int256 scaledEthPrice = ethPrice;

        if (usdcDecimals < crossDecimals) {
            scaledUsdcPrice = usdcPrice * int256(10 ** (crossDecimals - usdcDecimals));
        }
        if (ethDecimals < crossDecimals) {
            scaledEthPrice = ethPrice * int256(10 ** (crossDecimals - ethDecimals));
        }

        int256 manualCrossRate = (scaledUsdcPrice * int256(10 ** crossDecimals)) / scaledEthPrice;

        assertEq(crossRate, manualCrossRate);

        assertGt(scaledUsdcPrice, 0);
        assertGt(scaledEthPrice, 0);
        assertGe(scaledUsdcPrice, usdcPrice);
        assertGe(scaledEthPrice, ethPrice);
    }

    /// @notice fuzz test cross-rate calculation
    function testFuzz_crossRateCalculation(uint80 roundId) public {
        if (roundId == 0 || roundId > latestRoundId || roundId < latestRoundId - 100) {
            return;
        }

        try crossRatePriceFeed.getRoundData(roundId) returns (
            uint80 returnedRoundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound
        ) {
            if (answer > 0) {
                assertEq(returnedRoundId, roundId);
                assertGt(answer, 0);
                assertGt(startedAt, 0);
                assertGt(updatedAt, 0);
                assertGt(answeredInRound, 0);

                assertLt(uint256(answer), 1e8);
                assertGt(uint256(answer), 1e3);
            }
        } catch {}
    }

    /// @notice test cross-rate edge cases
    function test_crossRateEdgeCases() public {
        (, int256 crossRate,,,) = crossRatePriceFeed.latestRoundData();
        (, int256 usdcUsdPrice,,,) = usdcUsdFeed.latestRoundData();
        (, int256 ethUsdPrice,,,) = ethUsdFeed.latestRoundData();

        assertApproxEqAbs(uint256(usdcUsdPrice), 1e8, 1e6);
        assertGt(uint256(ethUsdPrice), 1000e8);

        int256 expectedInverse = int256(10 ** 16) / ethUsdPrice;
        uint256 tolerance = uint256(expectedInverse) / 100;
        assertApproxEqAbs(uint256(crossRate), uint256(expectedInverse), tolerance);
    }

    /// @notice helper function to calculate absolute value
    function abs(int256 x) internal pure returns (int256) {
        return x >= 0 ? x : -x;
    }
}
