// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {InstructionLib} from "../libraries/Instruction.sol";
import {AssemblyUtils} from "./libraries/AssemblyUtils.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {
    IMulticallOnceAction,
    INSTRUCTION_TYPEHASH,
    MULTICALL_ONCE_TYPEHASH,
    SUBCALL_TYPEHASH
} from "./interfaces/IMulticallOnceAction.sol";

import {InvalidArguments, InsufficientBalance, SubcallFailed} from "./errors/Errors.sol";

/// @title MulticallOnceAction
/// @author Otim Labs, Inc.
/// @notice an Action that performs a one-time multicall
contract MulticallOnceAction is IAction, IMulticallOnceAction, OtimFee {
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
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (MulticallOnce))));
    }

    /// @inheritdoc IMulticallOnceAction
    function hash(MulticallOnce memory arguments) public pure returns (bytes32) {
        // hash each subcall and store the hashes in an array
        bytes32[] memory subcallHashes = new bytes32[](arguments.subcalls.length);
        for (uint16 i; i < arguments.subcalls.length; i++) {
            subcallHashes[i] = hash(arguments.subcalls[i]);
        }

        return keccak256(
            abi.encode(MULTICALL_ONCE_TYPEHASH, keccak256(abi.encodePacked(subcallHashes)), hash(arguments.fee))
        );
    }

    /// @inheritdoc IMulticallOnceAction
    function hash(Subcall memory subcall) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                SUBCALL_TYPEHASH,
                subcall.target,
                subcall.allowFailure,
                subcall.value,
                subcall.gasLimit,
                subcall.returnSizeLimit,
                subcall.selector,
                keccak256(subcall.data)
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
        MulticallOnce memory arguments = abi.decode(instruction.arguments, (MulticallOnce));

        // ensure only one execution is possible
        if (instruction.maxExecutions != 1) {
            revert InvalidArguments();
        }

        for (uint16 i; i < arguments.subcalls.length; i++) {
            Subcall memory subcall = arguments.subcalls[i];
            /// @dev we block calls to InstructionStorage as to not break its access control invariant
            if (subcall.target == address(0) || subcall.target == instructionStorageAddress) {
                revert InvalidArguments();
            }

            // check if the user has enough balance to transfer
            if (address(this).balance < subcall.value) {
                revert InsufficientBalance();
            }

            // perform the external call with a gas limit and a return data size limit
            (bool success, bytes memory result) = subcall.target.safeCallLimitReturn(
                subcall.value,
                subcall.gasLimit,
                subcall.returnSizeLimit,
                abi.encodePacked(subcall.selector, subcall.data)
            );

            if (!success && !subcall.allowFailure) {
                revert SubcallFailed(i, subcall.target, subcall.selector, result);
            } else if (!success) {
                emit SubcallAttempted(i, subcall.target, subcall.selector, result);
            } else {
                emit SubcallSucceeded(i, subcall.target, subcall.selector, result);
            }
        }

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this action has no auto-deactivation paths
        return false;
    }
}
