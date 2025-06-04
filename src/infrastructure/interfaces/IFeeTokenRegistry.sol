// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

/// @title FeeTokenRegistry
/// @author Otim Labs, Inc.
/// @notice interface for the FeeTokenRegistry contract
interface IFeeTokenRegistry {
    /// @notice fee token data struct
    /// @param priceFeed - a price feed of the form <token>/ETH
    /// @param heartbeat - the time in seconds between price feed updates
    /// @param priceFeedDecimals - the number of decimals for the price feed
    /// @param tokenDecimals - the number of decimals for the token
    /// @param registered - whether the token is registered
    struct FeeTokenData {
        address priceFeed;
        uint40 heartbeat;
        uint8 priceFeedDecimals;
        uint8 tokenDecimals;
        bool registered;
    }

    /// @notice emitted when a fee token is added
    event FeeTokenAdded(
        address indexed token, address indexed priceFeed, uint40 heartbeat, uint8 priceFeedDecimals, uint8 tokenDecimals
    );
    /// @notice emitted when a fee token is removed
    event FeeTokenRemoved(
        address indexed token, address indexed priceFeed, uint40 heartbeat, uint8 priceFeedDecimals, uint8 tokenDecimals
    );

    error InvalidFeeTokenData();
    error PriceFeedNotInitialized();
    error FeeTokenAlreadyRegistered();
    error FeeTokenNotRegistered();
    error InvalidPrice();
    error StalePrice();

    /// @notice adds a fee token to the registry
    /// @param token - the ERC20 token address
    /// @param priceFeed - the price feed address
    /// @param heartbeat - the time in seconds between price feed updates
    function addFeeToken(address token, address priceFeed, uint40 heartbeat) external;

    /// @notice removes a fee token from the registry
    /// @param token - the ERC20 token address
    function removeFeeToken(address token) external;

    /// @notice converts a wei amount to a token amount
    /// @param token - the ERC20 token address to convert to
    /// @param weiAmount - the amount of wei to convert
    /// @return tokenAmount - converted token amount
    function weiToToken(address token, uint256 weiAmount) external view returns (uint256);
}
