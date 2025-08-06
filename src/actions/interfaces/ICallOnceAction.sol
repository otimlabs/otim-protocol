// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,CallOnce callOnce)CallOnce(address target,bool allowFailure,uint256 value,uint256 gasLimit,uint16 returnSizeLimit,bytes4 selector,bytes data,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "CallOnce(address target,bool allowFailure,uint256 value,uint256 gasLimit,uint16 returnSizeLimit,bytes4 selector,bytes data,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title ICallOnceAction
/// @author Otim Labs, Inc.
/// @notice interface for CallOnceAction contract
interface ICallOnceAction is IOtimFee {
    /// @notice arguments for the CallOnceAction contract
    /// @param target - the address to call
    /// @param allowFailure - whether to allow the call to fail
    /// @param value - the amount to transfer
    /// @param gasLimit - the gas limit for the call
    /// @param returnSizeLimit - the maximum return data size for the external call in bytes
    /// @param selector - the function selector
    /// @param data - the call data
    /// @param fee - the fee Otim will charge for the call
    struct CallOnce {
        address target;
        bool allowFailure;
        uint256 value;
        uint256 gasLimit;
        uint16 returnSizeLimit;
        bytes4 selector;
        bytes data;
        Fee fee;
    }

    /// @notice emitted when the CallOnceAction succeeds
    event CallOnceSucceeded(address indexed target, bytes4 indexed selector, bytes result);

    /// @notice emitted when the CallOnceAction fails but is allowed to fail
    event CallOnceAttempted(address indexed target, bytes4 indexed selector, bytes result);

    /// @notice calculates the EIP-712 hash of the CallOnce struct
    function hash(CallOnce memory arguments) external pure returns (bytes32);
}
