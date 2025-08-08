// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {InstructionLib} from "../libraries/Instruction.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {IRefuelERC20Action, INSTRUCTION_TYPEHASH, ARGUMENTS_TYPEHASH} from "./interfaces/IRefuelERC20Action.sol";

import {InvalidArguments, InsufficientBalance, BalanceOverThreshold} from "./errors/Errors.sol";

/// @title RefuelERC20
/// @author Otim Labs, Inc.
/// @notice an Action that refuels a target address with an ERC20 token when the target's balance is below a threshold
contract RefuelERC20Action is IAction, IRefuelERC20Action, OtimFee {
    using SafeERC20 for IERC20;

    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (RefuelERC20))));
    }

    /// @inheritdoc IRefuelERC20Action
    function hash(RefuelERC20 memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.token,
                arguments.target,
                arguments.threshold,
                arguments.endBalance,
                hash(arguments.fee)
            )
        );
    }

    /// @inheritdoc IAction
    function execute(
        InstructionLib.Instruction calldata instruction,
        InstructionLib.Signature calldata,
        InstructionLib.ExecutionState calldata executionState
    ) external override returns (bool) {
        // initial gas measurement for fee calculation
        uint256 startGas = gasleft();

        // decode the arguments from the instruction
        RefuelERC20 memory arguments = abi.decode(instruction.arguments, (RefuelERC20));

        // if first execution, validate the input
        if (executionState.executionCount == 0) {
            // validate the arguments
            if (
                arguments.token == address(0) || arguments.target == address(0)
                    || arguments.threshold >= arguments.endBalance
            ) {
                revert InvalidArguments();
            }
        }

        IERC20 refuelToken = IERC20(arguments.token);

        // get the target's ERC20 balance
        uint256 balance = refuelToken.balanceOf(arguments.target);

        // if the balance is above the threshold, revert
        if (balance > arguments.threshold) {
            revert BalanceOverThreshold();
        }

        // calculate the amount to refuel
        uint256 refuelAmount = arguments.endBalance - balance;

        // check if the account has enough balance to refuel
        if (refuelToken.balanceOf(address(this)) < refuelAmount) {
            revert InsufficientBalance();
        }

        // transfer the refuel amount to the target
        refuelToken.safeTransfer(arguments.target, refuelAmount);

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this action has no auto-deactivation cases
        return false;
    }
}
