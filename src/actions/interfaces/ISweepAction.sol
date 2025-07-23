// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,Sweep sweep)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Sweep(address target,uint256 threshold,uint256 endBalance,uint256 gasLimit,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "Sweep(address target,uint256 threshold,uint256 endBalance,uint256 gasLimit,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title ISweepAction
/// @author Otim Labs, Inc.
/// @notice interface for SweepAction contract
interface ISweepAction is IOtimFee {
    /// @notice arguments for the SweepAction contract
    /// @param target - the target address to sweep to
    /// @param threshold - the user's balance threshold to trigger the sweep
    /// @param endBalance - the user's balance after the sweep
    /// @param gasLimit - the maximum amount of gas the sweep external call can consume
    /// @param fee - the fee Otim will charge for the sweep
    struct Sweep {
        address payable target;
        uint256 threshold;
        uint256 endBalance;
        uint256 gasLimit;
        Fee fee;
    }

    /// @notice emitted when the Sweep fails
    event SweepActionFailed(address indexed target);

    /// @notice calculates the EIP-712 hash of the Sweep struct
    function hash(Sweep memory arguments) external pure returns (bytes32);
}
