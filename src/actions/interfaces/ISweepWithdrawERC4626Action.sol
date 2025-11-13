// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,SweepWithdrawERC4626 sweepWithdrawERC4626)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)SweepWithdrawERC4626(address vault,address recipient,uint256 threshold,uint256 endBalance,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "SweepWithdrawERC4626(address vault,address recipient,uint256 threshold,uint256 endBalance,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)"
);

/// @title ISweepWithdrawERC4626Action
/// @author Otim Labs, Inc.
/// @notice interface for SweepWithdrawERC4626Action contract
interface ISweepWithdrawERC4626Action is IOtimFee {
    /// @notice arguments for the SweepWithdrawERC4626Action contract
    /// @param vault - the address of the ERC4626 vault to withdraw from
    /// @param recipient - the address to receive shares
    /// @param threshold - the account's maxWithdraw threshold to trigger the sweep
    /// @param endBalance - the account's maxWithdraw balance after the sweep
    /// @param fee - the fee Otim will charge for the withdraw
    struct SweepWithdrawERC4626 {
        address vault;
        address recipient;
        uint256 threshold;
        uint256 endBalance;
        Fee fee;
    }

    /// @notice emitted when the max withdraw is reached
    event MaxWithdrawReached(uint256 maxWithdraw, uint256 newEndBalance);

    /// @notice calculates the EIP-712 hash of the SweepWithdrawERC4626 struct
    function hash(SweepWithdrawERC4626 memory arguments) external pure returns (bytes32);
}
