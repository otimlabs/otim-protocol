// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,MulticallOnce multicallOnce)MulticallOnce(Subcall[] subcalls,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Subcall(address target,bool allowFailure,uint256 value,uint256 gasLimit,uint16 returnSizeLimit,bytes4 selector,bytes data)"
);

bytes32 constant MULTICALL_ONCE_TYPEHASH = keccak256(
    "MulticallOnce(Subcall[] subcalls,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Subcall(address target,bool allowFailure,uint256 value,uint256 gasLimit,uint16 returnSizeLimit,bytes4 selector,bytes data)"
);

bytes32 constant SUBCALL_TYPEHASH = keccak256(
    "Subcall(address target,bool allowFailure,uint256 value,uint256 gasLimit,uint16 returnSizeLimit,bytes4 selector,bytes data)"
);

/// @title IMulticallOnceAction
/// @author Otim Labs, Inc.
/// @notice interface for MulticallOnceAction contract
interface IMulticallOnceAction is IOtimFee {
    /// @notice arguments for the MulticallOnceAction contract
    /// @param calls - the calls to make
    /// @param fee - the fee Otim will charge for the call
    struct MulticallOnce {
        Subcall[] subcalls;
        Fee fee;
    }

    /// @notice arguments for the Subcall struct
    /// @param target - the address to call
    /// @param allowFailure - whether to allow the sub-call to fail
    /// @param value - the amount to transfer
    /// @param gasLimit - the gas limit for the sub-call
    /// @param returnSizeLimit - the maximum return data size for the external sub-call in bytes
    /// @param selector - the function selector
    /// @param data - the sub-call data
    struct Subcall {
        address target;
        bool allowFailure;
        uint256 value;
        uint256 gasLimit;
        uint16 returnSizeLimit;
        bytes4 selector;
        bytes data;
    }

    /// @notice emitted when the MulticallOnceAction succeeds
    event SubcallSucceeded(uint16 indexed index, address indexed target, bytes4 indexed selector, bytes result);

    /// @notice emitted when the MulticallOnceAction fails but is allowed to fail
    event SubcallAttempted(uint16 indexed index, address indexed target, bytes4 indexed selector, bytes result);

    /// @notice calculates the EIP-712 hash of the MulticallOnce struct
    function hash(MulticallOnce memory arguments) external pure returns (bytes32);

    /// @notice calculates the EIP-712 hash of the Subcall struct
    function hash(Subcall memory subcall) external pure returns (bytes32);
}
