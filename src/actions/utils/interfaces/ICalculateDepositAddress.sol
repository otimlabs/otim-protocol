// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

/// @title ICalculateDepositAddress
/// @author Otim Labs, Inc.
/// @notice interface for the CalculateDepositAddress contract
interface ICalculateDepositAddress {
    /// @notice calculates the address of a deposit account using Create2
    /// @param owner - the owner of the deposit account
    /// @param depositor - the depositor for the deposit account
    /// @return depositAddress - the address of the deposit account
    function calculateDepositAddress(address owner, address depositor) external pure returns (address);
}
