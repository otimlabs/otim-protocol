// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,SweepRequestDepositERC7540 sweepRequestDepositERC7540)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)SweepRequestDepositERC7540(address vault,address controller,uint256 threshold,uint256 endBalance,uint256 minDeposit,uint256 minTotalShares,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "SweepRequestDepositERC7540(address vault,address controller,uint256 threshold,uint256 endBalance,uint256 minDeposit,uint256 minTotalShares,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title ISweepRequestDepositERC7540Action
/// @author Otim Labs, Inc.
/// @notice interface for SweepRequestDepositERC7540Action contract
interface ISweepRequestDepositERC7540Action is IOtimFee {
    /// @notice arguments for the SweepRequestDepositERC7540Action contract
    /// @param vault - the address of the ERC7540 vault to request deposit to
    /// @param controller - the ERC7540 controller for the request
    /// @param threshold - the account's underlying balance threshold to trigger the sweep
    /// @param endBalance - the account's balance after the sweep
    /// @param minDeposit - the minimum deposit amount to trigger the sweep
    /// @param minTotalShares - the minimum total shares of the vault before the request
    /// @param fee - the fee Otim will charge for the request
    struct SweepRequestDepositERC7540 {
        address vault;
        address controller;
        uint256 threshold;
        uint256 endBalance;
        uint256 minDeposit;
        uint256 minTotalShares;
        Fee fee;
    }

    /// @notice calculates the EIP-712 hash of the SweepRequestDepositERC7540 struct
    function hash(SweepRequestDepositERC7540 memory arguments) external pure returns (bytes32);
}
