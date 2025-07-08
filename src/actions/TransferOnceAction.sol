// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {InstructionLib} from "../libraries/Instruction.sol";
import {AssemblyUtils} from "./libraries/AssemblyUtils.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {ITransferOnceAction, INSTRUCTION_TYPEHASH, ARGUMENTS_TYPEHASH} from "./interfaces/ITransferOnceAction.sol";

import {InvalidArguments, InsufficientBalance} from "./errors/Errors.sol";

/// @title TransferOnceAction
/// @author Otim Labs, Inc.
/// @notice an Action that makes a one-time native currency transfer to a target address
contract TransferOnceAction is IAction, ITransferOnceAction, OtimFee {
    using InstructionLib for InstructionLib.Instruction;

    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (TransferOnce))));
    }

    /// @inheritdoc ITransferOnceAction
    function hash(TransferOnce memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(ARGUMENTS_TYPEHASH, arguments.target, arguments.value, arguments.gasLimit, hash(arguments.fee))
        );
    }

    /// @inheritdoc IAction
    function execute(
        InstructionLib.Instruction calldata instruction,
        InstructionLib.Signature calldata,
        InstructionLib.ExecutionState calldata
    ) external override returns (bool deactivate) {
        // initial gas measurement for fee calculation
        uint256 startGas = gasleft();

        // decode the arguments from the instruction
        TransferOnce memory arguments = abi.decode(instruction.arguments, (TransferOnce));

        // validate the arguments
        if (instruction.maxExecutions != 1 || arguments.target == address(0) || arguments.value == 0) {
            revert InvalidArguments();
        }

        // check if the account has enough balance to transfer
        if (address(this).balance < arguments.value) {
            revert InsufficientBalance();
        }

        // transfer the value to the target address, with a gas limit, and without returning any data
        bool success = AssemblyUtils.safeTransferNoReturn(arguments.target, arguments.value, arguments.gasLimit);

        // if the transfer fails, charge the user for gas used, emit an event, and automatically deactivate the instruction
        // we do this instead of reverting to protect the Executor from gas griefing attacks
        if (!success) {
            // if the fee is not sponsored, set the execution fee to 1 to only charge the user for gas used
            if (arguments.fee.executionFee > 0) {
                arguments.fee.executionFee = 1;
            }

            // emit that the transfer failed
            emit TransferOnceActionFailed(arguments.target);

            // deactivate the instruction
            deactivate = true;
        }

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);
    }
}
