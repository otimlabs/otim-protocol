// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,SweepDepositERC4626 sweepDepositERC4626)SweepDepositERC4626(address vault,address recipient,uint256 threshold,uint256 endBalance,uint256 minDeposit,uint256 minTotalShares,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "SweepDepositERC4626(address vault,address recipient,uint256 threshold,uint256 endBalance,uint256 minDeposit,uint256 minTotalShares,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title ISweepDepositERC4626Action
/// @author Otim Labs, Inc.
/// @notice interface for SweepDepositERC4626Action contract
interface ISweepDepositERC4626Action is IOtimFee {
    /// @notice arguments for the SweepDepositERC4626Action contract
    /// @param vault - the address of the ERC4626 vault to deposit to
    /// @param recipient - the address to receive shares
    /// @param threshold - the account's balance threshold to trigger the sweep
    /// @param endBalance - the account's balance after the sweep
    /// @param minDeposit - the minimum deposit amount to trigger the sweep
    /// @param minTotalShares - the minimum total shares of the vault before the deposit
    /// @param fee - the fee Otim will charge for the deposit
    struct SweepDepositERC4626 {
        address vault;
        address recipient;
        uint256 threshold;
        uint256 endBalance;
        uint256 minDeposit;
        uint256 minTotalShares;
        Fee fee;
    }

    /// @notice emitted when the max deposit is reached
    event MaxDepositReached(uint256 maxDeposit, uint256 newEndBalance);

    /// @notice calculates the EIP-712 hash of the SweepDepositERC4626 struct
    function hash(SweepDepositERC4626 memory arguments) external pure returns (bytes32);
}
