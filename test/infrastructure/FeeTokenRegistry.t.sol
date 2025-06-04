// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/src/Test.sol";
import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {ERC20MockWithDecimals} from "../mocks/ERC20MockWithDecimals.sol";
import {MockV3Aggregator} from "@chainlink-contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";

import {FeeTokenRegistry} from "../../src/infrastructure/FeeTokenRegistry.sol";
import {IFeeTokenRegistry} from "../../src/infrastructure/interfaces/IFeeTokenRegistry.sol";

contract FeeTokenRegistryTest is Test {
    FeeTokenRegistry public feeTokenRegistry = new FeeTokenRegistry(address(this));

    constructor() {
        /// @notice set up VM block.timestamp
        vm.warp(vm.unixTime());
    }

    /// @notice test that addFeeToken works properly under normal conditions
    function test_addFeeToken_happyPath() public {
        vm.pauseGasMetering();

        ERC20MockWithDecimals usdt = new ERC20MockWithDecimals(18);
        MockV3Aggregator usdtPriceFeed = new MockV3Aggregator(18, int256(1_000_000_000));
        uint40 priceFeedHeartbeat = 1 days;

        vm.expectEmit();

        emit IFeeTokenRegistry.FeeTokenAdded(address(usdt), address(usdtPriceFeed), priceFeedHeartbeat, 18, 18);

        vm.resumeGasMetering();
        feeTokenRegistry.addFeeToken(address(usdt), address(usdtPriceFeed), priceFeedHeartbeat);
        vm.pauseGasMetering();

        (address priceFeed, uint40 heartbeat, uint8 priceFeedDecimals, uint8 tokenDecimals, bool registered) =
            feeTokenRegistry.feeTokenData(address(usdt));

        assertEq(priceFeed, address(usdtPriceFeed));
        assertEq(priceFeedDecimals, 18);
        assertEq(heartbeat, priceFeedHeartbeat);
        assertEq(tokenDecimals, 18);
        assertTrue(registered);
    }

    /// @notice test that addFeeToken reverts if the token is already registered
    function test_addFeeToken_alreadyRegistered() public {
        vm.pauseGasMetering();

        ERC20MockWithDecimals usdt = new ERC20MockWithDecimals(18);
        MockV3Aggregator usdtPriceFeed = new MockV3Aggregator(18, int256(1_000_000_000));
        uint40 priceFeedHeartbeat = 1 days;

        feeTokenRegistry.addFeeToken(address(usdt), address(usdtPriceFeed), priceFeedHeartbeat);

        vm.expectRevert(abi.encodeWithSelector(IFeeTokenRegistry.FeeTokenAlreadyRegistered.selector));

        vm.resumeGasMetering();
        feeTokenRegistry.addFeeToken(address(usdt), address(usdtPriceFeed), priceFeedHeartbeat);
        vm.pauseGasMetering();
    }

    /// @notice test that addFeeToken reverts with token = address(0)
    function test_addFeeToken_zeroToken() public {
        vm.pauseGasMetering();

        MockV3Aggregator usdtPriceFeed = new MockV3Aggregator(8, int256(1_000_000_000));
        uint40 priceFeedHeartbeat = 1 days;

        vm.expectRevert(abi.encodeWithSelector(IFeeTokenRegistry.InvalidFeeTokenData.selector));

        vm.resumeGasMetering();
        feeTokenRegistry.addFeeToken(address(0), address(usdtPriceFeed), priceFeedHeartbeat);
        vm.pauseGasMetering();
    }

    /// @notice test that addFeeToken reverts with priceFeed = address(0)
    function test_addFeeToken_zeroPriceFeed() public {
        vm.pauseGasMetering();

        ERC20MockWithDecimals usdt = new ERC20MockWithDecimals(18);
        uint40 priceFeedHeartbeat = 1 days;

        vm.expectRevert(abi.encodeWithSelector(IFeeTokenRegistry.InvalidFeeTokenData.selector));

        vm.resumeGasMetering();
        feeTokenRegistry.addFeeToken(address(usdt), address(0), priceFeedHeartbeat);
        vm.pauseGasMetering();
    }

    /// @notice test that addFeeToken reverts with heartbeat = 0
    function test_addFeeToken_zeroHeartbeat() public {
        vm.pauseGasMetering();

        ERC20MockWithDecimals usdt = new ERC20MockWithDecimals(18);
        MockV3Aggregator usdtPriceFeed = new MockV3Aggregator(8, int256(1_000_000_000));

        vm.expectRevert(abi.encodeWithSelector(IFeeTokenRegistry.InvalidFeeTokenData.selector));

        vm.resumeGasMetering();
        feeTokenRegistry.addFeeToken(address(usdt), address(usdtPriceFeed), 0);
        vm.pauseGasMetering();
    }

    /// @notice test that addFeeToken reverts if the price feed has not been initialized
    function test_addFeeToken_roundIdZero() public {
        vm.pauseGasMetering();

        ERC20MockWithDecimals usdt = new ERC20MockWithDecimals(18);
        MockV3Aggregator usdtPriceFeed = new MockV3Aggregator(18, int256(1_000_000_000));
        uint40 priceFeedHeartbeat = 1 days;

        usdtPriceFeed.updateRoundData(0, int256(1_000_000_000), 1, 1);

        vm.expectRevert(abi.encodeWithSelector(IFeeTokenRegistry.PriceFeedNotInitialized.selector));

        vm.resumeGasMetering();
        feeTokenRegistry.addFeeToken(address(usdt), address(usdtPriceFeed), priceFeedHeartbeat);
        vm.pauseGasMetering();
    }

    /// @notice test that addFeeToken reverts if the price feed has not been updated for the first time
    function test_addFeeToken_updatedAtZero() public {
        vm.pauseGasMetering();

        ERC20MockWithDecimals usdt = new ERC20MockWithDecimals(18);
        MockV3Aggregator usdtPriceFeed = new MockV3Aggregator(18, int256(1_000_000_000));
        uint40 priceFeedHeartbeat = 1 days;

        usdtPriceFeed.updateRoundData(1, int256(1_000_000_000), 0, 1);

        vm.expectRevert(abi.encodeWithSelector(IFeeTokenRegistry.PriceFeedNotInitialized.selector));

        vm.resumeGasMetering();
        feeTokenRegistry.addFeeToken(address(usdt), address(usdtPriceFeed), priceFeedHeartbeat);
        vm.pauseGasMetering();
    }

    /// @notice test that removeFeeToken works properly under normal conditions
    function test_removeFeeToken_happyPath() public {
        vm.pauseGasMetering();

        ERC20MockWithDecimals usdt = new ERC20MockWithDecimals(18);
        MockV3Aggregator usdtPriceFeed = new MockV3Aggregator(18, int256(1_000_000_000));
        uint40 priceFeedHeartbeat = 1 days;

        feeTokenRegistry.addFeeToken(address(usdt), address(usdtPriceFeed), priceFeedHeartbeat);

        vm.expectEmit();

        emit IFeeTokenRegistry.FeeTokenRemoved(address(usdt), address(usdtPriceFeed), priceFeedHeartbeat, 18, 18);

        vm.resumeGasMetering();
        feeTokenRegistry.removeFeeToken(address(usdt));
        vm.pauseGasMetering();

        (address priceFeed, uint40 heartbeat, uint8 priceFeedDecimals, uint8 tokenDecimals, bool registered) =
            feeTokenRegistry.feeTokenData(address(usdt));

        assertEq(priceFeed, address(0));
        assertEq(priceFeedDecimals, 0);
        assertEq(heartbeat, 0);
        assertEq(tokenDecimals, 0);
        assertFalse(registered);
    }

    /// @notice test that removeFeeToken reverts if the token is not already registered
    function test_removeFeeToken_notRegistered() public {
        vm.pauseGasMetering();

        ERC20MockWithDecimals usdt = new ERC20MockWithDecimals(18);

        vm.expectRevert(abi.encodeWithSelector(IFeeTokenRegistry.FeeTokenNotRegistered.selector));

        vm.resumeGasMetering();
        feeTokenRegistry.removeFeeToken(address(usdt));
        vm.pauseGasMetering();
    }

    /// @notice test that weiToToken reverts if the token is not registered
    function test_weiToToken_tokenNotRegistered() public {
        vm.pauseGasMetering();

        ERC20MockWithDecimals usdt = new ERC20MockWithDecimals(18);

        vm.expectRevert(abi.encodeWithSelector(IFeeTokenRegistry.FeeTokenNotRegistered.selector));

        vm.resumeGasMetering();
        feeTokenRegistry.weiToToken(address(usdt), 1 ether);
        vm.pauseGasMetering();
    }

    /// @notice test that weiToToken reverts if lastestPrice <= 0
    function test_weiToToken_latestPriceNegative() public {
        vm.pauseGasMetering();

        ERC20MockWithDecimals usdt = new ERC20MockWithDecimals(18);
        MockV3Aggregator usdtPriceFeed = new MockV3Aggregator(18, int256(-1));
        uint40 priceFeedHeartbeat = 1 days;

        feeTokenRegistry.addFeeToken(address(usdt), address(usdtPriceFeed), priceFeedHeartbeat);

        vm.expectRevert(abi.encodeWithSelector(IFeeTokenRegistry.InvalidPrice.selector));

        vm.resumeGasMetering();
        feeTokenRegistry.weiToToken(address(usdt), 1 ether);
        vm.pauseGasMetering();
    }

    /// @notice test that weiToToken reverts if the price feed has not been updated in the last heartbeat duration
    function test_weiToToken_stalePriceFeed() public {
        vm.pauseGasMetering();

        ERC20MockWithDecimals usdt = new ERC20MockWithDecimals(18);
        MockV3Aggregator usdtPriceFeed = new MockV3Aggregator(18, int256(1_000_000_000));
        uint40 priceFeedHeartbeat = 1 days;

        usdtPriceFeed.updateRoundData(1, int256(1_000_000_000), block.timestamp - priceFeedHeartbeat - 1, 1);

        feeTokenRegistry.addFeeToken(address(usdt), address(usdtPriceFeed), priceFeedHeartbeat);

        vm.expectRevert(abi.encodeWithSelector(IFeeTokenRegistry.StalePrice.selector));

        vm.resumeGasMetering();
        feeTokenRegistry.weiToToken(address(usdt), 1 ether);
        vm.pauseGasMetering();
    }

    /// @notice fuzz test to make sure that wei --> ERC20 token conversion doesn't result in an arithmetic overflow or underflow with reasonably bounded input
    function test_weiToToken_overflow(int256 firstAnswer, uint256 gasUsed, uint64 blockBaseFee) public {
        vm.pauseGasMetering();

        // the gas used for an Instruction must be below the block gas limit which is 30 million gas
        vm.assume(gasUsed < 30_000_000);

        // set block.basefee to blockBaseFee
        vm.fee(blockBaseFee);

        uint256 weiAmount = gasUsed * blockBaseFee;

        uint8 tokenDecimals = 18;
        uint8 priceFeedDecimals = 18;

        ERC20MockWithDecimals token = new ERC20MockWithDecimals(tokenDecimals);
        MockV3Aggregator tokenPriceFeed = new MockV3Aggregator(priceFeedDecimals, firstAnswer);
        uint40 priceFeedHeartbeat = 1 days;

        feeTokenRegistry.addFeeToken(address(token), address(tokenPriceFeed), priceFeedHeartbeat);

        if (firstAnswer <= 0) {
            vm.expectRevert(abi.encodeWithSelector(IFeeTokenRegistry.InvalidPrice.selector));
        }

        vm.resumeGasMetering();
        feeTokenRegistry.weiToToken(address(token), weiAmount);
        vm.pauseGasMetering();
    }

    /// @notice fuzz test to make sure that wei --> ERC20 token conversion doesn't result in an arithmetic overflow or underflow with reasonably bounded input
    function test_weiToToken_underflow(int256 firstAnswer, uint256 gasUsed, uint64 blockBaseFee) public {
        vm.pauseGasMetering();

        // the gas used for an Instruction must be below the block gas limit which is 30 million gas
        vm.assume(gasUsed < 30_000_000);

        // set block.basefee to blockBaseFee
        vm.fee(blockBaseFee);

        uint256 weiAmount = gasUsed * blockBaseFee;

        uint8 tokenDecimals = 6;
        uint8 priceFeedDecimals = 8;

        ERC20MockWithDecimals token = new ERC20MockWithDecimals(tokenDecimals);
        MockV3Aggregator tokenPriceFeed = new MockV3Aggregator(priceFeedDecimals, firstAnswer);
        uint40 priceFeedHeartbeat = 1 days;

        feeTokenRegistry.addFeeToken(address(token), address(tokenPriceFeed), priceFeedHeartbeat);

        if (firstAnswer <= 0) {
            vm.expectRevert(abi.encodeWithSelector(IFeeTokenRegistry.InvalidPrice.selector));
        }

        vm.resumeGasMetering();
        feeTokenRegistry.weiToToken(address(token), weiAmount);
        vm.pauseGasMetering();
    }

    /// @notice test that weiToToken works properly with a token that has 6 decimals
    function test_weiToToken_correctnessUSDT() public {
        vm.pauseGasMetering();

        ERC20MockWithDecimals usdt = new ERC20MockWithDecimals(6);
        MockV3Aggregator usdtPriceFeed = new MockV3Aggregator(18, 408761777224494);
        uint40 priceFeedHeartbeat = 1 days;

        feeTokenRegistry.addFeeToken(address(usdt), address(usdtPriceFeed), priceFeedHeartbeat);

        vm.resumeGasMetering();
        uint256 result = feeTokenRegistry.weiToToken(address(usdt), 1 ether);
        vm.pauseGasMetering();

        assertEq(result, 2_446_412_692);

        result = feeTokenRegistry.weiToToken(address(usdt), 1 gwei);
        assertEq(result, 2);

        result = feeTokenRegistry.weiToToken(address(usdt), 0.1 gwei);
        assertEq(result, 0);
    }

    /// @notice test that weiToToken works properly with a token that has 18 decimals
    function test_weiToToken_correctnessDAI() public {
        vm.pauseGasMetering();

        ERC20MockWithDecimals dai = new ERC20MockWithDecimals(18);
        MockV3Aggregator daiPriceFeed = new MockV3Aggregator(18, 408761777224494);
        uint40 priceFeedHeartbeat = 1 days;

        feeTokenRegistry.addFeeToken(address(dai), address(daiPriceFeed), priceFeedHeartbeat);

        vm.resumeGasMetering();
        uint256 result = feeTokenRegistry.weiToToken(address(dai), 1 ether);
        vm.pauseGasMetering();

        assertEq(result, 2_446_412_692_473_433_074_971);

        result = feeTokenRegistry.weiToToken(address(dai), 1 gwei);
        assertEq(result, 2_446_412_692_473);

        result = feeTokenRegistry.weiToToken(address(dai), 1 wei);
        assertEq(result, 2_446);
    }
}
