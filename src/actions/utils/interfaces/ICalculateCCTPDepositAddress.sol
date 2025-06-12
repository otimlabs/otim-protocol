// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

/// @title ICalculateCCTPDepositAddress
/// @author Otim Labs, Inc.
/// @notice interface for the CalculateCCTPDepositAddress contract
interface ICalculateCCTPDepositAddress {
    /// @notice calculates the address of a CCTPDepositAccount using Create2
    /// @param owner - the owner of the deposit account
    /// @param depositor - the depositor for the deposit account
    /// @return depositAddress - the address of the deposit account
    function calculateCCTPDepositAddress(address owner, address depositor) external view returns (address);
}
