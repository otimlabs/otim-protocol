// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {AggregatorV3Interface} from "@chainlink-contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {IFeeTokenRegistry} from "./interfaces/IFeeTokenRegistry.sol";

/// @title FeeTokenRegistry
/// @author Otim Labs, Inc.
/// @notice a contract for registering ERC20 fee tokens and using price feeds to convert wei amounts to ERC20 token amounts
contract FeeTokenRegistry is IFeeTokenRegistry, Ownable {
    /// @notice relates a token address to its price feed and decimal information
    mapping(address => FeeTokenData) public feeTokenData;

    constructor(address owner) Ownable(owner) {}

    /// @inheritdoc IFeeTokenRegistry
    function addFeeToken(address token, address priceFeed, uint40 heartbeat) external onlyOwner {
        // basic checks to ensure the token, price feed, and heartbeat are valid
        if (token == address(0) || priceFeed == address(0) || heartbeat == 0) {
            revert InvalidFeeTokenData();
        }

        // ensure the token is not already registered
        if (feeTokenData[token].registered) {
            revert FeeTokenAlreadyRegistered();
        }

        // query the lastest round data from the price feed
        // slither-disable-next-line unused-return
        (uint80 roundId,,, uint256 updatedAt,) = AggregatorV3Interface(priceFeed).latestRoundData();

        // check if the price feed has been initialized
        if (roundId == 0 || updatedAt == 0) {
            revert PriceFeedNotInitialized();
        }

        // query the decimals for the token and price feed
        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        uint8 priceFeedDecimals = AggregatorV3Interface(priceFeed).decimals();

        // store this information in the feeTokenData mapping
        feeTokenData[token] = FeeTokenData(priceFeed, heartbeat, priceFeedDecimals, tokenDecimals, true);

        // emit an event to notify listeners of the new fee token
        emit FeeTokenAdded(token, priceFeed, heartbeat, priceFeedDecimals, tokenDecimals);
    }

    /// @inheritdoc IFeeTokenRegistry
    function removeFeeToken(address token) external onlyOwner {
        // query the fee token data
        FeeTokenData memory data = feeTokenData[token];

        // if the token is not registered, revert
        if (!data.registered) {
            revert FeeTokenNotRegistered();
        }

        // delete the fee token data from the mapping
        delete feeTokenData[token];

        // emit an event to notify listeners of the removed fee token
        emit FeeTokenRemoved(token, data.priceFeed, data.heartbeat, data.priceFeedDecimals, data.tokenDecimals);
    }

    /// @inheritdoc IFeeTokenRegistry
    function weiToToken(address token, uint256 weiAmount) external view override returns (uint256) {
        // query the fee token data
        FeeTokenData memory data = feeTokenData[token];

        // if the token is not registered, revert
        if (!data.registered) {
            revert FeeTokenNotRegistered();
        }

        // query the latest price from the price feed
        // slither-disable-next-line unused-return
        (, int256 latestPrice,, uint256 updatedAt,) = AggregatorV3Interface(data.priceFeed).latestRoundData();

        // if the latest price is zero or negative, revert
        if (latestPrice <= 0) {
            revert InvalidPrice();
        }

        // if the price feed is stale, revert
        if (block.timestamp - updatedAt > data.heartbeat) {
            revert StalePrice();
        }

        // collect the number of decimals for the token and price feed
        uint8 decimals = data.priceFeedDecimals + data.tokenDecimals;

        // adjust the tokenAmount based on the number of decimals.
        // we must divide by 10 ** 18 at some point since the price is given in ether
        // so we adjust the tokenAmount based on the difference in decimals
        if (decimals < 18) {
            return weiAmount / 10 ** (18 - decimals) / uint256(latestPrice);
        } else {
            return weiAmount * 10 ** (decimals - 18) / uint256(latestPrice);
        }
    }
}
