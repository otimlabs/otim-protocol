// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

/// @title ICalculateCCTPDepositAddress
/// @author Otim Labs, Inc.
/// @notice interface for the CalculateCCTPDepositAddress contract
interface ICalculateCCTPDepositAddress {
    /// @notice calculates the address of a CCTPDepositAccount using Create2
    /// @param owner - the owner of the deposit account
    /// @param depositor - the depositor for the deposit account
    /// @param destinationDomain - the domain ID of the destination chain
    /// @param destinationMintRecipient - the address of the mint recipient for the CCTP transfer (in bytes32 format)
    /// @return depositAddress - the address of the deposit account
    function calculateDepositAddress(
        address owner,
        address depositor,
        uint32 destinationDomain,
        bytes32 destinationMintRecipient
    ) external view returns (address);
}
