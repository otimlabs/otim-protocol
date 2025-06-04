// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {InstructionLib} from "../libraries/Instruction.sol";
import {AssemblyUtils} from "./libraries/AssemblyUtils.sol";

import {Interval} from "./schedules/Interval.sol";
import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {ITransferAction, INSTRUCTION_TYPEHASH, ARGUMENTS_TYPEHASH} from "./interfaces/ITransferAction.sol";

import {InvalidArguments, InsufficientBalance} from "./errors/Errors.sol";

/// @title TransferAction
/// @author Otim Labs, Inc.
/// @notice an Action that transfers native currency to a target address
contract TransferAction is IAction, ITransferAction, Interval, OtimFee {
    using InstructionLib for InstructionLib.Instruction;

    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (Transfer))));
    }

    /// @inheritdoc ITransferAction
    function hash(Transfer memory transfer) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                transfer.target,
                transfer.value,
                transfer.gasLimit,
                hash(transfer.schedule),
                hash(transfer.fee)
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
        Transfer memory transfer = abi.decode(instruction.arguments, (Transfer));

        // if first execution, validate the input
        if (executionState.executionCount == 0) {
            // validate the arguments
            if (transfer.target == address(0) || transfer.value == 0) {
                revert InvalidArguments();
            }

            checkStart(transfer.schedule);
        } else {
            checkInterval(transfer.schedule, executionState.lastExecuted);
        }

        // check if the account has enough balance to transfer
        if (address(this).balance < transfer.value) {
            revert InsufficientBalance();
        }

        // transfer the value to the target address, with a gas limit, and without returning any data
        bool success = AssemblyUtils.safeTransferNoReturn(transfer.target, transfer.value, transfer.gasLimit);

        // if the transfer fails, charge the user for gas used, emit an event, and automatically deactivate the instruction
        // we do this instead of reverting to protect the Executor from gas griefing attacks
        if (!success) {
            // if the fee is not sponsored, set the execution fee to 1 to only charge the user for gas used
            if (transfer.fee.executionFee > 0) {
                transfer.fee.executionFee = 1;
            }

            // emit that the transfer failed
            emit TransferActionFailed(transfer.target);

            // deactivate the instruction
            deactivate = true;
        }

        // charge the fee
        chargeFee(startGas - gasleft(), transfer.fee);
    }
}
