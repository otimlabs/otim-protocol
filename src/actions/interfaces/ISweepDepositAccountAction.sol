// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";
import {ICalculateDepositAddress} from "../utils/interfaces/ICalculateDepositAddress.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,SweepDepositAccount sweepDepositAccount)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)SweepDepositAccount(address depositor,address recipient,uint256 threshold,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "SweepDepositAccount(address depositor,address recipient,uint256 threshold,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title ISweepDepositAccountAction
/// @author Otim Labs, Inc.
/// @notice interface for SweepDepositAccountAction contract
interface ISweepDepositAccountAction is IOtimFee, ICalculateDepositAddress {
    /// @notice arguments for SweepDepositAccountAction contract
    /// @param depositor - the address of the depositor
    /// @param recipient - the address of the sweep recipient
    /// @param threshold - the sweep threshold
    /// @param fee - the fee to be paid
    struct SweepDepositAccount {
        address depositor;
        address payable recipient;
        uint256 threshold;
        Fee fee;
    }

    /// @notice calculates the EIP-712 hash of the SweepDepositAccount struct
    /// @param arguments - the arguments to hash
    /// @return argumentsHash - the EIP-712 hash of the arguments
    function hash(SweepDepositAccount memory arguments) external pure returns (bytes32);
}
