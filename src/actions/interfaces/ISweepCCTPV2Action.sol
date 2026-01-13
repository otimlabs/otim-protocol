// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,SweepCCTPV2 sweepCCTPV2)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)SweepCCTPV2(address token,uint32 destinationDomain,bytes32 destinationMintRecipient,uint256 threshold,uint256 endBalance,bytes32 destinationCaller,uint256 maxFee,uint32 minFinalityThreshold,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "SweepCCTPV2(address token,uint32 destinationDomain,bytes32 destinationMintRecipient,uint256 threshold,uint256 endBalance,bytes32 destinationCaller,uint256 maxFee,uint32 minFinalityThreshold,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title ISweepCCTPV2Action
/// @author Otim Labs, Inc.
/// @notice interface for SweepCCTPV2Action contract
interface ISweepCCTPV2Action is IOtimFee {
    /// @notice arguments for SweepCCTPV2Action contract
    /// @param token - the token to sweep
    /// @param destinationDomain - the destination domain for the CCTP transfer
    /// @param destinationMintRecipient - the address of the mint recipient for the CCTP transfer (in bytes32 format)
    /// @param threshold - the sweep threshold
    /// @param endBalance - the account's balance after the sweep
    /// @param destinationCaller - the address allowed to call receiveMessage on destination (bytes32(0) for anyone)
    /// @param maxFee - the maximum fee for the transfer in burn token units
    /// @param minFinalityThreshold - minimum finality threshold (e.g., 1000=fast, 2000=standard)
    /// @param fee - the fee to be paid
    struct SweepCCTPV2 {
        address token;
        uint32 destinationDomain;
        bytes32 destinationMintRecipient;
        uint256 threshold;
        uint256 endBalance;
        bytes32 destinationCaller;
        uint256 maxFee;
        uint32 minFinalityThreshold;
        Fee fee;
    }

    /// @notice emitted when the CCTP burn limit is reached
    /// @param token - the token being transferred
    /// @param burnLimitPerMessage - the burn limit per message for the token
    event CCTPBurnLimitReached(address indexed token, uint256 burnLimitPerMessage);

    /// @notice calculates the EIP-712 hash of the SweepCCTPV2 struct
    /// @param arguments - the arguments to hash
    /// @return argumentsHash - the EIP-712 hash of the arguments
    function hash(SweepCCTPV2 memory arguments) external pure returns (bytes32);
}

