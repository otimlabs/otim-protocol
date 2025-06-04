// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";
import {ICalculateDepositAddress} from "../utils/interfaces/ICalculateDepositAddress.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,SweepDepositAccountERC20 sweepDepositAccountERC20)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)SweepDepositAccountERC20(address token,address depositor,address recipient,uint256 threshold,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "SweepDepositAccountERC20(address token,address depositor,address recipient,uint256 threshold,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title ISweepDepositAccountERC20Action
/// @author Otim Labs, Inc.
/// @notice interface for SweepDepositAccountERC20Action contract
interface ISweepDepositAccountERC20Action is IOtimFee, ICalculateDepositAddress {
    /// @notice arguments for SweepDepositAccountERC20Action contract
    /// @param token - the address of the token to sweep
    /// @param depositor - the address of the depositor
    /// @param recipient - the address of the sweep recipient
    /// @param threshold - the sweep threshold
    /// @param fee - the fee to be paid
    struct SweepDepositAccountERC20 {
        address token;
        address depositor;
        address recipient;
        uint256 threshold;
        Fee fee;
    }

    /// @notice calculates the EIP-712 hash of the SweepDepositAccountERC20 struct
    /// @param arguments - the arguments to hash
    /// @return argumentsHash - the EIP-712 hash of the arguments
    function hash(SweepDepositAccountERC20 memory arguments) external pure returns (bytes32);
}
