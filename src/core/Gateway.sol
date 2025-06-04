// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Constants} from "../libraries/Constants.sol";
import {InstructionLib} from "../libraries/Instruction.sol";

import {IGateway} from "./interfaces/IGateway.sol";
import {IOtimDelegate} from "../IOtimDelegate.sol";

/// @title Gateway
/// @author Otim Labs, Inc.
/// @notice a helper contract that protects the Otim Executor from delegation front-running attacks
contract Gateway is IGateway {
    /// @notice hash of the "delegation designator" i.e. keccak256(0xef0100 || delegate_address)
    bytes32 public immutable designatorHash;

    constructor() {
        designatorHash = keccak256(abi.encodePacked(Constants.EIP7702_PREFIX, msg.sender));
    }

    /// @inheritdoc IGateway
    function isDelegated(address target) external view override returns (bool) {
        return target.codehash == designatorHash;
    }

    /// @inheritdoc IGateway
    function safeExecuteInstruction(
        address target,
        InstructionLib.Instruction calldata instruction,
        InstructionLib.Signature calldata signature
    ) external {
        // revert if the target is not delegated to OtimDelegate at runtime
        if (target.codehash != designatorHash) {
            revert TargetNotDelegated();
        }

        // execute the Instruction on the target account
        IOtimDelegate(target).executeInstruction(instruction, signature);
    }

    /// @inheritdoc IGateway
    function safeExecuteInstruction(address target, InstructionLib.Instruction calldata instruction) external {
        // revert if the target is not delegated to OtimDelegate at runtime
        if (target.codehash != designatorHash) {
            revert TargetNotDelegated();
        }

        // execute the Instruction on the target account with no signature
        IOtimDelegate(target).executeInstruction(instruction, InstructionLib.Signature(0, 0, 0));
    }

    /// @inheritdoc IGateway
    function safeDeactivateInstruction(
        address target,
        InstructionLib.InstructionDeactivation calldata deactivation,
        InstructionLib.Signature calldata signature
    ) external {
        // revert if the target is not delegated to OtimDelegate at runtime
        if (target.codehash != designatorHash) {
            revert TargetNotDelegated();
        }

        // execute the Instruction on the target account
        IOtimDelegate(target).deactivateInstruction(deactivation, signature);
    }
}
