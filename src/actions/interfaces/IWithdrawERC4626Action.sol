// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IInterval} from "../schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,WithdrawERC4626 withdrawERC4626)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)WithdrawERC4626(address vault,address recipient,uint256 value,uint256 minWithdraw,Schedule schedule,Fee fee)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "WithdrawERC4626(address vault,address recipient,uint256 value,uint256 minWithdraw,Schedule schedule,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)"
);

/// @title IWithdrawERC4626Action
/// @author Otim Labs, Inc.
/// @notice interface for WithdrawERC4626Action contract
interface IWithdrawERC4626Action is IInterval, IOtimFee {
    /// @notice arguments for the WithdrawERC4626Action contract
    /// @param vault - the address of the ERC4626 vault to withdraw from
    /// @param recipient - the address to receive shares
    /// @param value - the amount to withdraw
    /// @param minWithdraw - the minimum withdraw amount to trigger the withdraw
    /// @param schedule - the schedule parameters for the withdraw
    /// @param fee - the fee Otim will charge for the transfer
    struct WithdrawERC4626 {
        address vault;
        address recipient;
        uint256 value;
        uint256 minWithdraw;
        Schedule schedule;
        Fee fee;
    }

    /// @notice emitted when the max withdraw is reached
    event MaxWithdrawReached(uint256 maxWithdraw);

    /// @notice calculates the EIP-712 hash of the WithdrawERC4626 struct
    function hash(WithdrawERC4626 memory arguments) external pure returns (bytes32);
}
