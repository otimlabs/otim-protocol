// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";
import {ICalculateSkipCCTPDepositAddress} from "../utils/interfaces/ICalculateSkipCCTPDepositAddress.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,SweepSkipCCTPDepositAccount sweepSkipCCTPDepositAccount)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)SweepSkipCCTPDepositAccount(address depositor,uint32 destinationDomain,bytes32 destinationMintRecipient,uint256 threshold,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "SweepSkipCCTPDepositAccount(address depositor,uint32 destinationDomain,bytes32 destinationMintRecipient,uint256 threshold,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title ISweepSkipCCTPDepositAccountAction
/// @author Otim Labs, Inc.
/// @notice interface for SweepSkipCCTPDepositAccountAction contract
interface ISweepSkipCCTPDepositAccountAction is IOtimFee, ICalculateSkipCCTPDepositAddress {
    /// @notice arguments for SweepSkipCCTPDepositAccountAction contract
    /// @param depositor - the address of the depositor
    /// @param destinationDomain - the destination domain for the CCTP transfer
    /// @param destinationMintRecipient - the address of the mint recipient for the CCTP transfer (in bytes32 format)
    /// @param threshold - the sweep threshold
    /// @param fee - the fee to be paid
    struct SweepSkipCCTPDepositAccount {
        address depositor;
        uint32 destinationDomain;
        bytes32 destinationMintRecipient;
        uint256 threshold;
        Fee fee;
    }

    /// @notice calculates the EIP-712 hash of the SweepSkipCCTPDepositAccount struct
    /// @param arguments - the arguments to hash
    /// @return argumentsHash - the EIP-712 hash of the arguments
    function hash(SweepSkipCCTPDepositAccount memory arguments) external pure returns (bytes32);
}
