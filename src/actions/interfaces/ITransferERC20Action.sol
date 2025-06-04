// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IInterval} from "../schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,TransferERC20 transferERC20)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)TransferERC20(address token,address target,uint256 value,Schedule schedule,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "TransferERC20(address token,address target,uint256 value,Schedule schedule,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)"
);

/// @title ITransferERC20Action
/// @author Otim Labs, Inc.
/// @notice interface for TransferERC20 Action contract
interface ITransferERC20Action is IInterval, IOtimFee {
    /// @notice arguments for the TransferERC20Action contract
    /// @param token - the address of the ERC20 token to transfer
    /// @param target - the address to transfer to
    /// @param value - the amount to transfer
    /// @param schedule - the schedule parameters for the transfer
    /// @param fee - the fee Otim will charge for the transfer
    struct TransferERC20 {
        address token;
        address target;
        uint256 value;
        Schedule schedule;
        Fee fee;
    }

    /// @notice calculates the EIP-712 hash of the TransferERC20 struct
    function hash(TransferERC20 memory transferERC20) external pure returns (bytes32);
}
