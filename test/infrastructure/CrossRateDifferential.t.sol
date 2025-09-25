// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/src/Test.sol";
import {CrossRatePriceFeed} from "../../src/infrastructure/CrossRatePriceFeed.sol";
import {AggregatorV3Interface} from "@chainlink-contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract CrossRateDifferentialTest is Test {
    // Mainnet price feed addresses
    address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant USDC_USD_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

    address constant ETH_USDC_FEED = 0x986b5E1e1755e3C2440e960477f25201B0a8bbD4;

    CrossRatePriceFeed public crossRatePriceFeed;

    AggregatorV3Interface public ethUsdcFeed;

    uint40 constant ETH_USD_HEARTBEAT = 3600;
    uint40 constant USDC_USD_HEARTBEAT = 86400;

    constructor() {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", vm.rpcUrl("mainnet"));
        vm.createSelectFork(rpcUrl);

        crossRatePriceFeed = new CrossRatePriceFeed(USDC_USD_FEED, ETH_USD_FEED, USDC_USD_HEARTBEAT, ETH_USD_HEARTBEAT);

        ethUsdcFeed = AggregatorV3Interface(ETH_USDC_FEED);
    }

    /// @notice test that cross-rate latestRoundData returns approximately the same answer as the direct price feed
    function test_latestRoundData_realValuesFork() public view {
        // allow for a 1.5% delta
        uint256 percentDelta = 15;

        (, int256 crossRateAnswer,,,) = crossRatePriceFeed.latestRoundData();
        (, int256 directAnswer,,,) = ethUsdcFeed.latestRoundData();

        // USDC/ETH price feed has 18 decimals, so scale down by 10^10
        directAnswer /= int256(10 ** 10);

        // 1e18 is 100%, so multiply percent delta by 1e15 to get 1.5%
        assertApproxEqRel(crossRateAnswer, directAnswer, percentDelta * 1e15);
    }
}
