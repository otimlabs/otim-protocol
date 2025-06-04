// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,Refuel refuel)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Refuel(address target,uint256 threshold,uint256 endBalance,uint256 gasLimit,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "Refuel(address target,uint256 threshold,uint256 endBalance,uint256 gasLimit,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title IRefuelAction
/// @author Otim Labs, Inc.
/// @notice interface for RefuelAction contract
interface IRefuelAction is IOtimFee {
    /// @notice arguments for the RefuelAction contract
    /// @param target - the address to refuel
    /// @param threshold - the minimum balance required to refuel
    /// @param endBalance - the target balance after refueling
    /// @param gasLimit - the maximum amount of gas the refuel external call can consume
    /// @param fee - the fee Otim will charge for the refuel
    struct Refuel {
        address payable target;
        uint256 threshold;
        uint256 endBalance;
        uint256 gasLimit;
        Fee fee;
    }

    /// @notice emitted when the Refuel fails
    event RefuelActionFailed(address indexed target);

    /// @notice calculates the EIP-712 hash of the Refuel struct
    function hash(Refuel memory refuel) external pure returns (bytes32);
}
