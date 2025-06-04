// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

/// @title ITreasury
/// @author Otim Labs, Inc.
/// @notice interface for Treasury contract
interface ITreasury {
    /// @notice thrown when the owner tries to withdraw to the zero address
    error InvalidTarget();
    /// @notice thrown when the withdrawl fails
    error WithdrawalFailed(bytes result);
    /// @notice thrown when the owner tries to withdraw more than the contract balance
    error InsufficientBalance();

    /// @notice deposit ether into the treasury
    function deposit() external payable;

    /// @notice withdraw ether from the treasury
    /// @param to - the address to withdraw to
    /// @param value - the amount to withdraw
    function withdraw(address to, uint256 value) external;

    /// @notice withdraw ERC20 tokens from the treasury
    /// @param token - the ERC20 token to withdraw
    /// @param to - the address to withdraw to
    /// @param value - the amount to withdraw
    function withdrawERC20(address token, address to, uint256 value) external;
}
