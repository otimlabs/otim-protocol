// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,TransferERC20Once transferERC20Once)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)TransferERC20Once(address token,address target,uint256 value,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "TransferERC20Once(address token,address target,uint256 value,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title ITransferERC20OnceAction
/// @author Otim Labs, Inc.
/// @notice interface for TransferERC20OnceAction contract
interface ITransferERC20OnceAction is IOtimFee {
    /// @notice arguments for the TransferERC20OnceAction contract
    /// @param token - the address of the ERC20 token to transfer
    /// @param target - the address to transfer to
    /// @param value - the amount to transfer
    /// @param fee - the fee Otim will charge for the transfer
    struct TransferERC20Once {
        address token;
        address target;
        uint256 value;
        Fee fee;
    }

    /// @notice calculates the EIP-712 hash of the TransferERC20Once struct
    function hash(TransferERC20Once memory arguments) external pure returns (bytes32);
}
