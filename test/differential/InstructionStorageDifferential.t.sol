// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {Test, console} from "forge-std/src/Test.sol";
import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {InstructionStorage} from "../../src/core/InstructionStorage.sol";
import {InstructionStorageReference} from "../../src/core/references/InstructionStorageReference.sol";
import {IInstructionStorage} from "../../src/core/interfaces/IInstructionStorage.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

interface IDummyDelegate {
    function call_incrementExecutionCounter(bytes32 instructionId) external;

    function call_incrementAndDeactivate(bytes32 instructionId) external;

    function call_deactivateStorage(bytes32 instructionId) external;
}

/// @notice dummy contract to simulate OtimDelegate
contract DummyDelegate is IDummyDelegate {
    IInstructionStorage public immutable instructionStorage;

    constructor() {
        instructionStorage = new InstructionStorage();
    }

    function call_incrementExecutionCounter(bytes32 instructionId) public {
        instructionStorage.incrementExecutionCounter(instructionId);
    }

    function call_incrementAndDeactivate(bytes32 instructionId) public {
        instructionStorage.incrementAndDeactivate(instructionId);
    }

    function call_deactivateStorage(bytes32 instructionId) public {
        instructionStorage.deactivateStorage(instructionId);
    }
}

/// @notice dummy contract to simulate OtimDelegate
contract RefDummyDelegate is IDummyDelegate {
    IInstructionStorage public immutable instructionStorage;

    constructor() {
        instructionStorage = new InstructionStorageReference();
    }

    function call_incrementExecutionCounter(bytes32 instructionId) public {
        instructionStorage.incrementExecutionCounter(instructionId);
    }

    function call_incrementAndDeactivate(bytes32 instructionId) public {
        instructionStorage.incrementAndDeactivate(instructionId);
    }

    function call_deactivateStorage(bytes32 instructionId) public {
        instructionStorage.deactivateStorage(instructionId);
    }
}

contract InstructionStorageDifferential is Test {
    DummyDelegate delegate = new DummyDelegate();
    RefDummyDelegate refDelegate = new RefDummyDelegate();

    IInstructionStorage target = IInstructionStorage(delegate.instructionStorage());
    IInstructionStorage refTarget = IInstructionStorage(refDelegate.instructionStorage());

    VmSafe.Wallet userEOA = vm.createWallet("UserEOA");
    IDummyDelegate user = IDummyDelegate(userEOA.addr);

    VmSafe.Wallet refUserEOA = vm.createWallet("RefUserEOA");
    IDummyDelegate refUser = IDummyDelegate(refUserEOA.addr);

    InstructionLib.ExecutionState targetState;
    InstructionLib.ExecutionState refTargetState;

    Vm.Wallet owner = vm.createWallet("Owner");

    constructor() {
        vm.signAndAttachDelegation(address(delegate), userEOA.privateKey);
        vm.signAndAttachDelegation(address(refDelegate), refUserEOA.privateKey);
    }

    function testDiff_incrementExecutionCounter(bytes32 instructionId) public {
        vm.pauseGasMetering();

        uint256 interval = 1000;

        uint120 numRuns = 100;

        for (uint120 i = 0; i < numRuns; i++) {
            user.call_incrementExecutionCounter(instructionId);
            refUser.call_incrementExecutionCounter(instructionId);

            targetState = target.getExecutionState(address(user), instructionId);
            refTargetState = refTarget.getExecutionState(address(refUser), instructionId);

            _assertEqual(targetState, refTargetState);

            skip(interval);
        }
    }

    function testDiff_incrementAndDeactivate(bytes32 instructionId) public {
        vm.pauseGasMetering();

        uint256 interval = 1000;

        uint120 numRuns = 100;

        for (uint120 i = 0; i < numRuns; i++) {
            user.call_incrementExecutionCounter(instructionId);
            refUser.call_incrementExecutionCounter(instructionId);

            targetState = target.getExecutionState(address(user), instructionId);
            refTargetState = refTarget.getExecutionState(address(refUser), instructionId);

            _assertEqual(targetState, refTargetState);

            skip(interval);
        }

        user.call_incrementAndDeactivate(instructionId);
        refUser.call_incrementAndDeactivate(instructionId);

        targetState = target.getExecutionState(address(user), instructionId);
        refTargetState = refTarget.getExecutionState(address(refUser), instructionId);

        _assertEqual(targetState, refTargetState);
    }

    function testDiff_incrementAndDeactivate_beforeIncrementExecutionCounter(bytes32 instructionId) public {
        vm.pauseGasMetering();

        user.call_incrementAndDeactivate(instructionId);
        refUser.call_incrementAndDeactivate(instructionId);

        targetState = target.getExecutionState(address(user), instructionId);
        refTargetState = refTarget.getExecutionState(address(refUser), instructionId);

        _assertEqual(targetState, refTargetState);
    }

    function testDiff_deactivateStorage(bytes32 instructionId) public {
        vm.pauseGasMetering();

        uint256 interval = 1000;

        uint120 numRuns = 100;

        for (uint120 i = 0; i < numRuns; i++) {
            user.call_incrementExecutionCounter(instructionId);
            refUser.call_incrementExecutionCounter(instructionId);

            targetState = target.getExecutionState(address(user), instructionId);
            refTargetState = refTarget.getExecutionState(address(refUser), instructionId);

            _assertEqual(targetState, refTargetState);

            skip(interval);
        }

        user.call_deactivateStorage(instructionId);
        refUser.call_deactivateStorage(instructionId);

        targetState = target.getExecutionState(address(user), instructionId);
        refTargetState = refTarget.getExecutionState(address(refUser), instructionId);

        _assertEqual(targetState, refTargetState);
    }

    function testDiff_deactivateStorage_beforeExecution(bytes32 instructionId) public {
        vm.pauseGasMetering();

        user.call_deactivateStorage(instructionId);
        refUser.call_deactivateStorage(instructionId);

        targetState = target.getExecutionState(address(user), instructionId);
        refTargetState = refTarget.getExecutionState(address(refUser), instructionId);

        _assertEqual(targetState, refTargetState);
    }

    function _assertEqual(InstructionLib.ExecutionState memory a, InstructionLib.ExecutionState memory b)
        internal
        pure
    {
        assertEq(a.deactivated, b.deactivated);
        assertEq(a.executionCount, b.executionCount);
        assertEq(a.lastExecuted, b.lastExecuted);
    }
}
