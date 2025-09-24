// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IInterval} from "../schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,DepositERC4626 depositERC4626)DepositERC4626(address recipient,address vault,uint256 value,uint256 minTotalAssets,Schedule schedule,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "DepositERC4626(address recipient,address vault,uint256 value,uint256 minTotalAssets,Schedule schedule,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)"
);

/// @title IDepositERC4626Action
/// @author Otim Labs, Inc.
/// @notice interface for DepositERC4626Action contract
interface IDepositERC4626Action is IInterval, IOtimFee {
    /// @notice arguments for the DepositERC4626Action contract
    /// @param recipient - the address to receive shares
    /// @param vault - the address of the ERC4626 vault to deposit to
    /// @param value - the amount to deposit
    /// @param minTotalAssets - the minimum total assets of the vault before the deposit
    /// @param schedule - the schedule parameters for the deposit
    /// @param fee - the fee Otim will charge for the transfer
    struct DepositERC4626 {
        address recipient;
        address vault;
        uint256 value;
        uint256 minTotalAssets;
        Schedule schedule;
        Fee fee;
    }

    /// @notice emitted when the max deposit is reached
    event MaxDepositReached(uint256 maxDeposit);

    /// @notice calculates the EIP-712 hash of the DepositERC4626 struct
    function hash(DepositERC4626 memory arguments) external pure returns (bytes32);
}
