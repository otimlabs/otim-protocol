// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {InstructionLib} from "../libraries/Instruction.sol";
import {AssemblyUtils} from "./libraries/AssemblyUtils.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {IRefuelAction, INSTRUCTION_TYPEHASH, ARGUMENTS_TYPEHASH} from "./interfaces/IRefuelAction.sol";

import {InvalidArguments, InsufficientBalance, BalanceOverThreshold} from "./errors/Errors.sol";

/// @title Refuel
/// @author Otim Labs, Inc.
/// @notice an Action that refuels a target address with native currency when the target's balance is below a threshold
contract RefuelAction is IAction, IRefuelAction, OtimFee {
    using InstructionLib for InstructionLib.Instruction;

    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (Refuel))));
    }

    /// @inheritdoc IRefuelAction
    function hash(Refuel memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.target,
                arguments.threshold,
                arguments.endBalance,
                arguments.gasLimit,
                hash(arguments.fee)
            )
        );
    }

    /// @inheritdoc IAction
    function execute(
        InstructionLib.Instruction calldata instruction,
        InstructionLib.Signature calldata,
        InstructionLib.ExecutionState calldata executionState
    ) external override returns (bool deactivate) {
        // initial gas measurement for fee calculation
        uint256 startGas = gasleft();

        // decode the arguments from the instruction
        Refuel memory arguments = abi.decode(instruction.arguments, (Refuel));

        // if first execution, validate the input
        if (executionState.executionCount == 0) {
            // validate the arguments
            if (arguments.target == address(0) || arguments.threshold >= arguments.endBalance) {
                revert InvalidArguments();
            }
        }

        // get the target's balance
        uint256 balance = arguments.target.balance;

        // if the balance is above the threshold, revert
        if (balance > arguments.threshold) {
            revert BalanceOverThreshold();
        }

        // calculate the amount to refuel
        uint256 refuelAmount = arguments.endBalance - balance;

        // if the contract doesn't have enough balance to refuel, revert
        if (address(this).balance < refuelAmount) {
            revert InsufficientBalance();
        }

        // transfer the value to the target address, with a gas limit, and without returning any data
        bool success = AssemblyUtils.safeTransferNoReturn(arguments.target, refuelAmount, arguments.gasLimit);

        // if the transfer fails, charge the user for the gas used, emit an event, and automatically deactivate the instruction
        // we do this instead of reverting to protect the Executor from gas griefing attacks
        if (!success) {
            // if the fee is not sponsored, set the execution fee to 1 to only charge the user for gas used
            if (arguments.fee.executionFee > 0) {
                arguments.fee.executionFee = 1;
            }

            // emit that the refuel failed
            emit RefuelActionFailed(arguments.target);

            // deactivate the instruction
            deactivate = true;
        }

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);
    }
}
