// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IInterval} from "../schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,TransferCCTP transferCCTP)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)TransferCCTP(address token,uint256 amount,uint32 destinationDomain,bytes32 destinationMintRecipient,Schedule schedule,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "TransferCCTP(address token,uint256 amount,uint32 destinationDomain,bytes32 destinationMintRecipient,Schedule schedule,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)"
);

/// @title ITransferCCTPAction
/// @author Otim Labs, Inc.
/// @notice interface for TransferCCTPAction contract
interface ITransferCCTPAction is IInterval, IOtimFee {
    /// @notice arguments for TransferCCTPAction contract
    /// @param token - the token to transfer
    /// @param amount - the amount to transfer
    /// @param destinationDomain - the destination domain for the CCTP transfer
    /// @param destinationMintRecipient - the address of the mint recipient for the CCTP transfer (in bytes32 format)
    /// @param schedule - the schedule parameters for the transfer
    /// @param fee - the fee to be paid
    struct TransferCCTP {
        address token;
        uint256 amount;
        uint32 destinationDomain;
        bytes32 destinationMintRecipient;
        Schedule schedule;
        Fee fee;
    }

    /// @notice emitted when the CCTP burn limit is reached
    /// @param token - the token being transferred
    /// @param burnLimitPerMessage - the burn limit per message for the token
    event CCTPBurnLimitReached(address indexed token, uint256 burnLimitPerMessage);

    /// @notice calculates the EIP-712 hash of the TransferCCTP struct
    /// @param arguments - the arguments to hash
    /// @return argumentsHash - the EIP-712 hash of the arguments
    function hash(TransferCCTP memory arguments) external pure returns (bytes32);
}
