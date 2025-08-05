// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,SweepERC20 sweepERC20)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)SweepERC20(address token,address target,uint256 threshold,uint256 endBalance,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "SweepERC20(address token,address target,uint256 threshold,uint256 endBalance,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title ISweepERC20Action
/// @author Otim Labs, Inc.
/// @notice interface for SweepERC20Action contract
interface ISweepERC20Action is IOtimFee {
    /// @notice arguments for the SweepERC20Action contract
    /// @param token - the ERC20 token to sweep
    /// @param target - the target address to sweep to
    /// @param threshold - the account's balance threshold to trigger the sweep
    /// @param endBalance - the account's balance after the sweep
    /// @param fee - the fee Otim will charge for the sweep
    struct SweepERC20 {
        address token;
        address target;
        uint256 threshold;
        uint256 endBalance;
        Fee fee;
    }

    /// @notice calculates the EIP-712 hash of the SweepERC20 struct
    function hash(SweepERC20 memory arguments) external pure returns (bytes32);
}
