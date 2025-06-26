// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

/// @title ISkipGoFeeOracle
/// @author Otim Labs, Inc.
/// @notice interface for the SkipGoFeeOracle contract
interface ISkipGoFeeOracle {
    error FeeCannotBeZero();
    error RouteNotSupported();

    /// @notice sets the fee for a specific destination domain
    /// @param destinationDomain - the domain ID of the destination chain
    /// @param fee - the fee amount to be set
    function setFee(uint32 destinationDomain, uint256 fee) external;

    /// @notice removes the fee entry for a specific destination domain
    /// @param destinationDomain - the domain ID of the destination chain
    function removeFee(uint32 destinationDomain) external;

    /// @notice returns the fee for a specific destination domain
    /// @param destinationDomain - the domain ID of the destination chain
    /// @return fee - the fee amount for the specified token and destination domain
    function getFee(uint32 destinationDomain) external view returns (uint256);
}
