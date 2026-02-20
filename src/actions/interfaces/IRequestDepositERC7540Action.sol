// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IInterval} from "../schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../fee-models/interfaces/IOtimFee.sol";

bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
    "Instruction(uint256 salt,uint256 maxExecutions,address action,RequestDepositERC7540 requestDepositERC7540)RequestDepositERC7540(address vault,uint256 assets,address controller,uint256 minDeposit,uint256 minTotalShares,Schedule schedule,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)"
);

bytes32 constant ARGUMENTS_TYPEHASH = keccak256(
    "RequestDepositERC7540(address vault,uint256 assets,address controller,uint256 minDeposit,uint256 minTotalShares,Schedule schedule,Fee fee)Fee(address token,uint256 maxBaseFeePerGas,uint256 maxPriorityFeePerGas,uint256 executionFee)Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)"
);

/// @title IRequestDepositERC7540Action
/// @author Otim Labs, Inc.
/// @notice interface for RequestDepositERC7540Action contract
interface IRequestDepositERC7540Action is IInterval, IOtimFee {
    /// @notice arguments for the RequestDepositERC7540Action contract
    /// @param vault - the address of the ERC7540 vault to request deposit to
    /// @param assets - the amount of assets to request for deposit
    /// @param controller - the ERC7540 controller who can later claim the deposit
    /// @param minDeposit - the minimum deposit amount to trigger the request
    /// @param minTotalShares - the minimum total shares of the vault before the request
    /// @param schedule - the schedule parameters for the request
    /// @param fee - the fee Otim will charge for the request
    struct RequestDepositERC7540 {
        address vault;
        uint256 assets;
        address controller;
        uint256 minDeposit;
        uint256 minTotalShares;
        Schedule schedule;
        Fee fee;
    }

    /// @notice calculates the EIP-712 hash of the RequestDepositERC7540 struct
    function hash(RequestDepositERC7540 memory arguments) external pure returns (bytes32);
}
