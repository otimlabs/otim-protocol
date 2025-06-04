// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Constants} from "./Constants.sol";

/// @title InstructionLib
/// @author Otim Labs, Inc.
/// @notice a library defining the Instruction datatype and util functions
library InstructionLib {
    /// @notice defines a signature
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// @notice defines the ExecutionState datatype
    /// @param deactivated - whether the Instruction has been deactivated
    /// @param executionCount - the number of times the Instruction has been executed
    /// @param lastExecuted - the unix timestamp of the last time the Instruction was executed
    struct ExecutionState {
        bool deactivated;
        uint120 executionCount;
        uint120 lastExecuted;
    }

    /// @notice defines the Instruction datatype
    /// @param salt - a number to ensure the uniqueness of the Instruction
    /// @param maxExecutions - the maximum number of times the Instruction can be executed
    /// @param action - the address of the Action contract to be executed
    /// @param arguments - the arguments to be passed to the Action contract
    struct Instruction {
        uint256 salt;
        uint256 maxExecutions;
        address action;
        bytes arguments;
    }

    /// @notice abi.encodes and hashes an Instruction struct to create a unique Instruction identifier
    /// @param instruction - an Instruction struct to hash
    /// @return instructionId - unique identifier for the Instruction
    function id(Instruction calldata instruction) internal pure returns (bytes32) {
        return keccak256(abi.encode(instruction));
    }

    /// @notice calculates the EIP-712 hash for activating an Instruction
    /// @param instruction - an Instruction struct to hash
    /// @param domainSeparator - the EIP-712 domain separator for the verifying contract
    /// @return hash - EIP-712 hash for activating `instruction`
    function signingHash(
        Instruction calldata instruction,
        bytes32 domainSeparator,
        bytes32 instructionTypeHash,
        bytes32 argumentsHash
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                Constants.EIP712_PREFIX,
                domainSeparator,
                keccak256(
                    abi.encode(
                        instructionTypeHash,
                        instruction.salt,
                        instruction.maxExecutions,
                        instruction.action,
                        argumentsHash
                    )
                )
            )
        );
    }

    /// @notice defines a deactivation instruction
    /// @param instructionId - the unique identifier of the Instruction to deactivate
    struct InstructionDeactivation {
        bytes32 instructionId;
    }

    /// @notice the EIP-712 type-hash for an InstructionDeactivation
    bytes32 public constant DEACTIVATION_TYPEHASH = keccak256("InstructionDeactivation(bytes32 instructionId)");

    /// @notice calculates the EIP-712 hash for a InstructionDeactivation
    /// @param deactivation - an InstructionDeactivation struct to hash
    /// @param domainSeparator - the EIP-712 domain separator for the verifying contract
    /// @return hash - EIP-712 hash for the `deactivation`
    function signingHash(InstructionDeactivation calldata deactivation, bytes32 domainSeparator)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                Constants.EIP712_PREFIX,
                domainSeparator,
                keccak256(abi.encode(DEACTIVATION_TYPEHASH, deactivation.instructionId))
            )
        );
    }
}
