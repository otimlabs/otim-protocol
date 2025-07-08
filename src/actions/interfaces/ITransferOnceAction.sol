// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,TransferOnce transferOnce)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)TransferOnce(address target,uint256 value,uint256 gasLimit,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "TransferOnce(address target,uint256 value,uint256 gasLimit,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title ITransferOnceAction
/// @author Otim Labs, Inc.
/// @notice interface for TransferOnceAction contract
interface ITransferOnceAction is IOtimFee {
    /// @notice arguments for the TransferOnceAction contract
    /// @param target - the address to transfer to
    /// @param value - the amount to transfer
    /// @param gasLimit - the maximum amount of gas the transfer external call can consume
    /// @param fee - the fee Otim will charge for the transfer
    struct TransferOnce {
        address payable target;
        uint256 value;
        uint256 gasLimit;
        Fee fee;
    }

    /// @notice emitted when the Transfer fails
    event TransferOnceActionFailed(address indexed target);

    /// @notice calculates the EIP-712 hash of the Transfer struct
    function hash(TransferOnce memory arguments) external pure returns (bytes32);
}
