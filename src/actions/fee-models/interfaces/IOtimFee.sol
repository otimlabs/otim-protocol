// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

bytes32 constant FEE_TYPEHASH =
    keccak256("Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)");

/// @title IOtimFee
/// @author Otim Labs, Inc.
/// @notice interface for the OtimFee contract
interface IOtimFee {
    /// @notice fee struct
    /// @param token - the token to be used for the fee (address(0) for native currency)
    /// @param maxBaseFeePerGas - the maximum basefee per gas the user is willing to pay
    /// @param maxPriorityFeePerGas - the maximum priority fee per gas the user is willing to pay
    /// @param executionFee - fixed fee to be paid for each execution
    struct Fee {
        address token;
        uint256 maxBaseFeePerGas;
        uint256 maxPriorityFeePerGas;
        uint256 executionFee;
    }

    /// @notice calculates the EIP-712 hash of the Fee struct
    function hash(Fee memory fee) external pure returns (bytes32);

    /// @notice charges a fee for the Instruction execution
    /// @param gasUsed - amount of gas used during the Instruction execution
    /// @param fee - additional fee to be paid
    function chargeFee(uint256 gasUsed, Fee memory fee) external;

    error InsufficientFeeBalance();
    error BaseFeePerGasTooHigh();
    error PriorityFeePerGasTooHigh();
}
