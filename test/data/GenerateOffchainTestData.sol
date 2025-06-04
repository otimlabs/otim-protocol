// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {InstructionTestContext} from "../utils/InstructionTestContext.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";
import {OtimDelegate} from "../../src/OtimDelegate.sol";
import {IAction} from "../../src/actions/interfaces/IAction.sol";

import {TransferAction} from "../../src/actions/TransferAction.sol";
import {ITransferAction} from "../../src/actions/interfaces/ITransferAction.sol";

import {IInterval} from "../../src/actions/schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

/// @title GenerateOffchainTestData
/// @notice a contract to generate test data used to verify behavior in `otim-offchain` unit tests
contract GenerateOffchainTestData is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

    constructor() {
        TransferAction transfer = new TransferAction(address(0), address(0), 0);

        /// @notice Instruction defaults
        DEFAULT_MAX_EXECUTIONS = 5;
        DEFAULT_ACTION = address(transfer);
        DEFAULT_ARGS = abi.encode(
            ITransferAction.Transfer({
                target: payable(address(1)),
                value: 2,
                gasLimit: 3,
                schedule: IInterval.Schedule({startAt: 4, startBy: 5, interval: 6, timeout: 7}),
                fee: IOtimFee.Fee({token: address(0), maxBaseFeePerGas: 9, maxPriorityFeePerGas: 10, executionFee: 11})
            })
        );
    }

    /// @notice emits the test user address
    function test_generate_userAddress() public {
        vm.pauseGasMetering();

        emit log_named_address("User address", userEOA.addr);
    }

    /// @notice emits the test OtimDelegate address
    function test_generate_delegateAddress() public {
        vm.pauseGasMetering();

        emit log_named_address("delegateAddress", address(delegate));
    }

    /// @notice emits the test chainId
    function test_generate_chainId() public {
        vm.pauseGasMetering();

        emit log_named_uint("chainId", block.chainid);
    }

    /// @notice emits the test OtimDelegate domainSeparator
    function test_generate_domainSeparator() public {
        vm.pauseGasMetering();

        emit log_named_bytes32("domainSeparator", delegate.domainSeparator());
    }

    /// @notice emits the instructionId of the test Instruction
    function test_generate_instructionId() public {
        vm.pauseGasMetering();

        buildInstruction();

        bytes32 id = _id(instruction);

        emit log_named_bytes32("instructionId", id);
    }

    /// @notice emits the activationHash of the test Instruction
    function test_generate_signatureHash() public {
        vm.pauseGasMetering();

        buildInstruction();

        (bytes32 instructionTypeHash, bytes32 argumentsHash) =
            IAction(instruction.action).argumentsHash(instruction.arguments);

        bytes32 signingHash = _signingHash(instruction, delegate.domainSeparator(), instructionTypeHash, argumentsHash);

        emit log_named_bytes32("signingHash", signingHash);
    }

    /// @notice emits the activationSignature of the test Instruction
    function test_generate_instructionSignature() public {
        vm.pauseGasMetering();

        buildInstruction();

        emit log_named_bytes32("instructionSignature.r", instructionSig.r);
        emit log_named_bytes32("instructionSignature.s", instructionSig.s);
        emit log_named_uint("instructionSignature.v", instructionSig.v);
    }

    /// @notice emits the deactivationHash of the test Instruction
    function test_generate_deactivationHash() public {
        vm.pauseGasMetering();

        buildInstruction();

        emit log_named_bytes32("deactivationHash", deactivationHash);
    }
}
