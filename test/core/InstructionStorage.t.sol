// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/src/Test.sol";
import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {IInstructionStorage} from "../../src/core/interfaces/IInstructionStorage.sol";
import {InstructionStorage} from "../../src/core/InstructionStorage.sol";

/// @notice dummy contract to simulate OtimDelegate
contract DummyDelegate {
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

    function call_deactivate(bytes32 instructionId) public {
        instructionStorage.deactivateStorage(instructionId);
    }
}

interface IDummyDelegate {
    function call_incrementExecutionCounter(bytes32 instructionId) external;

    function call_incrementAndDeactivate(bytes32 instructionId) external;

    function call_deactivate(bytes32 instructionId) external;
}

contract InstructionStorageTest is Test {
    /// @notice test contracts
    DummyDelegate public delegate = new DummyDelegate();

    IInstructionStorage public target = IInstructionStorage(delegate.instructionStorage());

    VmSafe.Wallet public userEOA = vm.createWallet("UserEOA");
    IDummyDelegate public user = IDummyDelegate(userEOA.addr);

    /// @notice reusable Instruction vars
    bytes32 public instructionId = keccak256("47");
    uint256 public maxExecutions = 10;

    /// @notice reusable vars for reading InstructionStorage state
    InstructionLib.ExecutionState public executionState;

    constructor() {
        vm.signAndAttachDelegation(address(delegate), userEOA.privateKey);
    }

    /// @notice test access control for all functions
    function test_accessControl() public {
        vm.pauseGasMetering();

        /// @notice revert if called directly from an EOA
        vm.startBroadcast(address(user));

        vm.expectRevert(abi.encodeWithSelector(IInstructionStorage.DataCorruptionAttempted.selector));
        target.incrementExecutionCounter(instructionId);

        vm.expectRevert(abi.encodeWithSelector(IInstructionStorage.DataCorruptionAttempted.selector));
        target.incrementAndDeactivate(instructionId);

        vm.expectRevert(abi.encodeWithSelector(IInstructionStorage.DataCorruptionAttempted.selector));
        target.deactivateStorage(instructionId);

        // delegate the user to `otherDelegate` which is the same contract as `delegate` but has a different address
        // meaning the delegation designator will not match the one required by InstructionStorage
        DummyDelegate otherDelegate = new DummyDelegate();
        vm.signAndAttachDelegation(address(otherDelegate), userEOA.privateKey);
        user = IDummyDelegate(userEOA.addr);

        vm.expectRevert(abi.encodeWithSelector(IInstructionStorage.DataCorruptionAttempted.selector));
        user.call_incrementExecutionCounter(instructionId);

        vm.expectRevert(abi.encodeWithSelector(IInstructionStorage.DataCorruptionAttempted.selector));
        user.call_incrementAndDeactivate(instructionId);

        vm.expectRevert(abi.encodeWithSelector(IInstructionStorage.DataCorruptionAttempted.selector));
        user.call_deactivate(instructionId);

        vm.stopBroadcast();
    }

    /// @notice test increment execution counter
    function test_incrementExecutionCounter_happyPath() public {
        vm.pauseGasMetering();

        uint256 currentTime = block.timestamp;
        uint256 delay = 100;

        executionState = target.getExecutionState(address(user), instructionId);
        assertFalse(executionState.deactivated);
        assertEq(executionState.executionCount, 0);
        assertEq(executionState.lastExecuted, 0);

        for (uint256 i; i < maxExecutions - 1; i++) {
            vm.resumeGasMetering();
            user.call_incrementExecutionCounter(instructionId);
            vm.pauseGasMetering();

            executionState = target.getExecutionState(address(user), instructionId);
            assertFalse(executionState.deactivated);
            assertEq(executionState.executionCount, i + 1);
            assertEq(executionState.lastExecuted, currentTime + (delay * i));
            skip(delay);
        }

        vm.resumeGasMetering();
        user.call_incrementExecutionCounter(instructionId);
        vm.pauseGasMetering();

        executionState = target.getExecutionState(address(user), instructionId);
        assertFalse(executionState.deactivated);
        assertEq(executionState.executionCount, maxExecutions);
        assertEq(executionState.lastExecuted, currentTime + (delay * (maxExecutions - 1)));

        vm.stopPrank();
    }

    /// @notice test increment execution counter and deactivate
    function test_incrementAndDeactivate_happyPath() public {
        vm.pauseGasMetering();

        uint256 currentTime = block.timestamp;
        uint256 delay = 100;

        executionState = target.getExecutionState(address(user), instructionId);
        assertFalse(executionState.deactivated);
        assertEq(executionState.executionCount, 0);
        assertEq(executionState.lastExecuted, 0);

        for (uint256 i; i < maxExecutions - 1; i++) {
            vm.resumeGasMetering();
            user.call_incrementExecutionCounter(instructionId);
            vm.pauseGasMetering();

            executionState = target.getExecutionState(address(user), instructionId);
            assertFalse(executionState.deactivated);
            assertEq(executionState.executionCount, i + 1);
            assertEq(executionState.lastExecuted, currentTime + (delay * i));
            skip(delay);
        }

        vm.resumeGasMetering();
        user.call_incrementAndDeactivate(instructionId);
        vm.pauseGasMetering();

        executionState = target.getExecutionState(address(user), instructionId);
        assertTrue(executionState.deactivated);
        assertEq(executionState.executionCount, maxExecutions);
        assertEq(executionState.lastExecuted, currentTime + (delay * (maxExecutions - 1)));

        vm.stopPrank();
    }

    /// @notice test deactivate storage
    function test_deactivate_happyPath() public {
        vm.pauseGasMetering();

        uint256 currentTime = block.timestamp;
        uint256 delay = 100;

        vm.resumeGasMetering();
        user.call_incrementExecutionCounter(instructionId);
        vm.pauseGasMetering();

        executionState = target.getExecutionState(address(user), instructionId);
        assertFalse(executionState.deactivated);
        assertEq(executionState.executionCount, 1);
        assertEq(executionState.lastExecuted, currentTime);

        skip(delay);

        vm.resumeGasMetering();
        user.call_deactivate(instructionId);
        vm.pauseGasMetering();

        executionState = target.getExecutionState(address(user), instructionId);
        assertTrue(executionState.deactivated);
        assertEq(executionState.executionCount, 1);
        assertEq(executionState.lastExecuted, currentTime);
    }
}
