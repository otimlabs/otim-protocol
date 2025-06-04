// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IInterval} from "../schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,Transfer transfer)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)Transfer(address target,uint256 value,uint256 gasLimit,Schedule schedule,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "Transfer(address target,uint256 value,uint256 gasLimit,Schedule schedule,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)"
);

/// @title ITransferAction
/// @author Otim Labs, Inc.
/// @notice interface for TransferAction contract
interface ITransferAction is IInterval, IOtimFee {
    /// @notice arguments for the TransferAction contract
    /// @param target - the address to transfer to
    /// @param value - the amount to transfer
    /// @param gasLimit - the maximum amount of gas the transfer external call can consume
    /// @param schedule - the schedule parameters for the transfer
    /// @param fee - the fee Otim will charge for the transfer
    struct Transfer {
        address payable target;
        uint256 value;
        uint256 gasLimit;
        Schedule schedule;
        Fee fee;
    }

    /// @notice emitted when the Transfer fails
    event TransferActionFailed(address indexed target);

    /// @notice calculates the EIP-712 hash of the Transfer struct
    function hash(Transfer memory arguments) external pure returns (bytes32);
}
