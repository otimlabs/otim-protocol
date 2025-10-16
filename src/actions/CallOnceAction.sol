// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {InstructionLib} from "../libraries/Instruction.sol";
import {AssemblyUtils} from "./libraries/AssemblyUtils.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {ICallOnceAction, INSTRUCTION_TYPEHASH, ARGUMENTS_TYPEHASH} from "./interfaces/ICallOnceAction.sol";

import {InvalidArguments, InsufficientBalance, CallOnceFailed} from "./errors/Errors.sol";

/// @title CallOnceAction
/// @author Otim Labs, Inc.
/// @notice an Action that performs a one-time external call to a target address
contract CallOnceAction is IAction, ICallOnceAction, OtimFee {
    using InstructionLib for InstructionLib.Instruction;
    using AssemblyUtils for address;

    /// @notice the address of the InstructionStorage contract
    address public immutable instructionStorageAddress;

    constructor(
        address instructionStorageAddress_,
        address feeTokenRegistryAddress,
        address treasuryAddress,
        uint256 gasConstant_
    ) OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_) {
        // slither-disable-next-line missing-zero-check
        instructionStorageAddress = instructionStorageAddress_;
    }

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (CallOnce))));
    }

    /// @inheritdoc ICallOnceAction
    function hash(CallOnce memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.target,
                arguments.allowFailure,
                arguments.value,
                arguments.gasLimit,
                arguments.returnSizeLimit,
                arguments.selector,
                keccak256(arguments.data),
                hash(arguments.fee)
            )
        );
    }

    /// @inheritdoc IAction
    function execute(
        InstructionLib.Instruction calldata instruction,
        InstructionLib.Signature calldata,
        InstructionLib.ExecutionState calldata
    ) external override returns (bool) {
        // initial gas measurement for fee calculation
        uint256 startGas = gasleft();

        // decode the arguments from the instruction
        CallOnce memory arguments = abi.decode(instruction.arguments, (CallOnce));

        // validate the arguments
        /// @dev we block calls to InstructionStorage as to not break its access control invariant
        if (
            instruction.maxExecutions != 1 || arguments.target == address(0)
                || arguments.target == instructionStorageAddress
        ) {
            revert InvalidArguments();
        }

        // check if the user has enough balance to transfer
        if (address(this).balance < arguments.value) {
            revert InsufficientBalance();
        }

        // perform the external call with a gas limit and a return data size limit
        (bool success, bytes memory result) = arguments.target
            .safeCallLimitReturn(
                arguments.value,
                arguments.gasLimit,
                arguments.returnSizeLimit,
                abi.encodePacked(arguments.selector, arguments.data)
            );

        if (!success && !arguments.allowFailure) {
            // if the call failed and allowFailure is false, revert
            revert CallOnceFailed(arguments.target, arguments.selector, result);
        } else if (!success) {
            // if the call failed and allowFailure is true, emit an event
            emit CallOnceAttempted(arguments.target, arguments.selector, result);
        } else {
            // if the call succeeded, emit an event
            emit CallOnceSucceeded(arguments.target, arguments.selector, result);
        }

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this action has no auto-deactivation paths
        return false;
    }
}
