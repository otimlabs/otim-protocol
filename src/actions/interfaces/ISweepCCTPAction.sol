// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,SweepCCTP sweepCCTP)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)SweepCCTP(address token,uint32 destinationDomain,bytes32 destinationMintRecipient,uint256 threshold,uint256 endBalance,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "SweepCCTP(address token,uint32 destinationDomain,bytes32 destinationMintRecipient,uint256 threshold,uint256 endBalance,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title ISweepCCTPAction
/// @author Otim Labs, Inc.
/// @notice interface for SweepCCTPAction contract
interface ISweepCCTPAction is IOtimFee {
    /// @notice arguments for SweepCCTPAction contract
    /// @param token - the token to sweep
    /// @param destinationDomain - the destination domain for the CCTP transfer
    /// @param destinationMintRecipient - the address of the mint recipient for the CCTP transfer (in bytes32 format)
    /// @param threshold - the sweep threshold
    /// @param endBalance - the account's balance after the sweep
    /// @param fee - the fee to be paid
    struct SweepCCTP {
        address token;
        uint32 destinationDomain;
        bytes32 destinationMintRecipient;
        uint256 threshold;
        uint256 endBalance;
        Fee fee;
    }

    /// @notice emitted when the CCTP burn limit is reached
    /// @param token - the token being transferred
    /// @param burnLimitPerMessage - the burn limit per message for the token
    event CCTPBurnLimitReached(address indexed token, uint256 burnLimitPerMessage);

    /// @notice calculates the EIP-712 hash of the SweepCCTP struct
    /// @param arguments - the arguments to hash
    /// @return argumentsHash - the EIP-712 hash of the arguments
    function hash(SweepCCTP memory arguments) external pure returns (bytes32);
}
