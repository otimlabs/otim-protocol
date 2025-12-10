// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IInterval} from "../schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,TransferCCTPV2 transferCCTPV2)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)TransferCCTPV2(address token,uint256 amount,uint32 destinationDomain,bytes32 destinationMintRecipient,bytes32 destinationCaller,uint256 maxFee,uint8 transferSpeed,Schedule schedule,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "TransferCCTPV2(address token,uint256 amount,uint32 destinationDomain,bytes32 destinationMintRecipient,bytes32 destinationCaller,uint256 maxFee,uint8 transferSpeed,Schedule schedule,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)"
);

/// @title ITransferCCTPV2Action
/// @author Otim Labs, Inc.
/// @notice interface for TransferCCTPV2Action contract
interface ITransferCCTPV2Action is IInterval, IOtimFee {
    /// @notice transfer speed for CCTP V2 transfers
    /// @param FAST - fast transfer with lower finality (1000)
    /// @param STANDARD - standard transfer with higher finality (2000)
    enum TransferSpeed {
        FAST,
        STANDARD
    }

    /// @notice arguments for TransferCCTPV2Action contract
    /// @param token - the token to transfer
    /// @param amount - the amount to transfer
    /// @param destinationDomain - the destination domain for the CCTP transfer
    /// @param destinationMintRecipient - the address of the mint recipient for the CCTP transfer (in bytes32 format)
    /// @param destinationCaller - the address allowed to call receiveMessage on destination (bytes32(0) for anyone)
    /// @param maxFee - the maximum fee for the transfer in burn token units
    /// @param transferSpeed - the transfer speed (FAST or STANDARD)
    /// @param schedule - the schedule parameters for the transfer
    /// @param fee - the fee to be paid
    struct TransferCCTPV2 {
        address token;
        uint256 amount;
        uint32 destinationDomain;
        bytes32 destinationMintRecipient;
        bytes32 destinationCaller;
        uint256 maxFee;
        TransferSpeed transferSpeed;
        Schedule schedule;
        Fee fee;
    }

    /// @notice emitted when the CCTP burn limit is reached
    /// @param token - the token being transferred
    /// @param burnLimitPerMessage - the burn limit per message for the token
    event CCTPBurnLimitReached(address indexed token, uint256 burnLimitPerMessage);

    /// @notice calculates the EIP-712 hash of the TransferCCTPV2 struct
    /// @param arguments - the arguments to hash
    /// @return argumentsHash - the EIP-712 hash of the arguments
    function hash(TransferCCTPV2 memory arguments) external pure returns (bytes32);
}

