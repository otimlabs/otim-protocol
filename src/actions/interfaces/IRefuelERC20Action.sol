// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,RefuelERC20 refuelERC20)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)RefuelERC20(address token,address target,uint256 threshold,uint256 endBalance,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "RefuelERC20(address token,address target,uint256 threshold,uint256 endBalance,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title IRefuelERC20Action
/// @author Otim Labs, Inc.
/// @notice interface for RefuelERC20Action contract
interface IRefuelERC20Action is IOtimFee {
    /// @notice arguments for the RefuelERC20Action contract
    /// @param token - the address of the ERC20 token to refuel with
    /// @param target - the address to refuel
    /// @param threshold - the minimum balance required to refuel
    /// @param endBalance - the target balance after refueling
    /// @param fee - the fee Otim will charge for the refuel
    struct RefuelERC20 {
        address token;
        address target;
        uint256 threshold;
        uint256 endBalance;
        Fee fee;
    }

    /// @notice calculates the EIP-712 hash of the RefuelERC20 struct
    function hash(RefuelERC20 memory refuelERC20) external pure returns (bytes32);
}
