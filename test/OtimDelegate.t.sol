// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {IERC165} from "@openzeppelin-contracts/utils/introspection/IERC165.sol";
import {IERC721Receiver} from "@openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC1271} from "@openzeppelin-contracts/interfaces/IERC1271.sol";

import {InstructionTestContext} from "./utils/InstructionTestContext.sol";

import {InstructionLib} from "../src/libraries/Instruction.sol";
import {OtimDelegate} from "../src/OtimDelegate.sol";
import {ActionManager} from "../src/core/ActionManager.sol";

import {IOtimDelegate} from "../src/IOtimDelegate.sol";

import {HelloWorldAction} from "./mocks/HelloWorldAction.sol";

contract OtimDelegateTest is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;
    using InstructionLib for InstructionLib.InstructionDeactivation;

    HelloWorldAction.HelloWorld public DEFAULT_ACTION_ARGS = HelloWorldAction.HelloWorld("Hello, World!", 47);

    /// @notice reusable ExecutionState var
    InstructionLib.ExecutionState public executionState;

    constructor() {
        /// @notice Action setup
        HelloWorldAction action = new HelloWorldAction();

        actionManager.addAction(address(action));

        /// @notice Instruction defaults
        DEFAULT_MAX_EXECUTIONS = 5;
        DEFAULT_ACTION = address(action);
        DEFAULT_ARGS = abi.encode(DEFAULT_ACTION_ARGS);
    }

    /// @notice make sure state variables are set correctly
    function test_constructor() public {
        delegate = new OtimDelegate(address(this));
        vm.pauseGasMetering();

        bytes32 EIP712_DOMAIN_TYPEHASH =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)");

        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256("OtimDelegate"),
                keccak256("1"),
                block.chainid,
                address(delegate),
                keccak256("ON_TIME_INSTRUCTED_MONEY")
            )
        );

        assertEq(delegate.domainSeparator(), domainSeparator);
    }

    /// @notice test that EOA supports interfaces
    function test_supportsInterface() public view {
        assertTrue(user.supportsInterface(type(IOtimDelegate).interfaceId));
        assertTrue(user.supportsInterface(type(IERC721Receiver).interfaceId));
        assertTrue(user.supportsInterface(type(IERC1155Receiver).interfaceId));
        assertTrue(user.supportsInterface(type(IERC1271).interfaceId));
        assertTrue(user.supportsInterface(type(IERC165).interfaceId));
    }

    /// @notice test that isValidSignature returns the correct selector for a valid signature
    function test_isValidSignature_happyPath() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.resumeGasMetering();
        bytes4 selector = user.isValidSignature(
            instructionHash, abi.encodePacked(instructionSig.r, instructionSig.s, instructionSig.v)
        );
        vm.pauseGasMetering();

        assertTrue(selector == IERC1271.isValidSignature.selector);
    }

    /// @notice test that isValidSignature returns bytes4(0) for an invalid signature
    function test_isValidSignature_invalid() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.resumeGasMetering();
        bytes4 selector = user.isValidSignature(
            deactivationHash, abi.encodePacked(instructionSig.r, instructionSig.s, instructionSig.v)
        );
        vm.pauseGasMetering();

        assertTrue(selector != IERC1271.isValidSignature.selector);
    }

    /// @notice typical Instruciton execution flow
    function test_executeInstruction_happyPath() public {
        vm.pauseGasMetering();

        buildInstruction();

        executionState = instructionStorage.getExecutionState(address(user), instructionId);
        assertFalse(executionState.deactivated);
        assertEq(executionState.executionCount, 0);
        assertEq(executionState.lastExecuted, 0);

        vm.expectEmit();
        emit HelloWorldAction.EmitHelloWorld();

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        executionState = instructionStorage.getExecutionState(address(user), instructionId);
        assertFalse(executionState.deactivated);
        assertEq(executionState.executionCount, 1);
        assertEq(executionState.lastExecuted, block.timestamp);

        skip(1);

        for (uint256 i = 1; i < instruction.maxExecutions - 1; i++) {
            vm.expectEmit();
            emit HelloWorldAction.EmitHelloWorld();

            vm.expectEmit();
            emit IOtimDelegate.InstructionExecuted(instructionId, i + 1);

            vm.resumeGasMetering();
            user.executeInstruction(instruction, instructionSig);
            vm.pauseGasMetering();

            executionState = instructionStorage.getExecutionState(address(user), instructionId);
            assertFalse(executionState.deactivated);
            assertEq(executionState.executionCount, i + 1);
            assertEq(executionState.lastExecuted, block.timestamp);

            skip(1);
        }

        vm.expectEmit();
        emit HelloWorldAction.EmitHelloWorld();

        vm.expectEmit();
        emit IOtimDelegate.InstructionExecuted(instructionId, instruction.maxExecutions);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();

        executionState = instructionStorage.getExecutionState(address(user), instructionId);
        assertTrue(executionState.deactivated);
        assertEq(executionState.executionCount, instruction.maxExecutions);
        assertEq(executionState.lastExecuted, block.timestamp);
    }

    /// @notice if maxExecutions=0, Instruction can be executed unlimited times until deactivated
    function test_executeInstruction_maxExecutionsZero() public {
        vm.pauseGasMetering();

        buildInstruction(DEFAULT_SALT, 0, DEFAULT_ACTION, DEFAULT_ARGS);

        uint256 iterations = 100;

        for (uint256 i = 0; i < iterations; i++) {
            vm.resumeGasMetering();
            user.executeInstruction(instruction, instructionSig);
            vm.pauseGasMetering();

            executionState = instructionStorage.getExecutionState(address(user), instructionId);
            assertFalse(executionState.deactivated);
            assertEq(executionState.executionCount, i + 1);
            assertEq(executionState.lastExecuted, block.timestamp);

            skip(1);
        }
    }

    /// @notice can't replay an Instruction execution on a different chain
    function test_executeInstruction_wrongChainId() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.chainId(474747);

        OtimDelegate otherChainDelegate = new OtimDelegate(address(this));

        vm.signAndAttachDelegation(address(otherChainDelegate), userEOA.privateKey);

        ActionManager otherChainActionManager = ActionManager(address(otherChainDelegate.actionManager()));

        otherChainActionManager.addAction(DEFAULT_ACTION);

        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.InvalidSignature.selector, instructionId));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice can't execute a deactivated Instruction
    function test_executeInstruction_instructionAlreadyDeactivated() public {
        vm.pauseGasMetering();

        buildInstruction();

        user.executeInstruction(instruction, instructionSig);
        user.deactivateInstruction(deactivation, deactivationSig);

        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.InstructionAlreadyDeactivated.selector, instructionId));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice can't execute an Instruction with a non-existent Action
    function test_executeInstruction_actionDoesNotExist() public {
        vm.pauseGasMetering();

        buildInstruction();

        actionManager.removeAction(DEFAULT_ACTION);

        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionNotExecutable.selector, instructionId));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice can't activate or execute Instructions when ActionManager is locked
    function test_executeInstruction_actionLocked() public {
        vm.pauseGasMetering();

        buildInstruction();

        actionManager.lockAllActions();

        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionNotExecutable.selector, instructionId));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice can't execute an Instruction with invalid signature
    function test_executeInstruction_invalidSignature() public {
        vm.pauseGasMetering();

        buildInstruction();

        InstructionLib.Instruction memory badInstruction =
            InstructionLib.Instruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, bytes("blah"));
        bytes32 badInstructionId = _id(badInstruction);

        (uint8 b_v, bytes32 b_r, bytes32 b_s) = vm.sign(userEOA.privateKey, badInstructionId);
        InstructionLib.Signature memory badInstructionSig = InstructionLib.Signature(b_v, b_r, b_s);

        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.InvalidSignature.selector, instructionId));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, badInstructionSig);
        vm.pauseGasMetering();
    }

    /// @notice can't execute an Instruction twice in the same block (interval=0)
    function test_executeInstruction_sameBlock() public {
        vm.pauseGasMetering();

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, DEFAULT_ARGS);

        user.executeInstruction(instruction, instructionSig);

        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ExecutionSameBlock.selector, instructionId));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice can't execute an Instruction if Action reverts
    function test_executeInstruction_actionRevert() public {
        vm.pauseGasMetering();

        HelloWorldAction.HelloWorld memory bad_args = HelloWorldAction.HelloWorld("Hello World!", 48);

        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, abi.encode(bad_args));

        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.ActionExecutionFailed.selector, instructionId, bytes("")));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test the Instruction gets deactivated after maxExecutions is reached
    function test_executeInstruction_maxExecutionsReached() public {
        vm.pauseGasMetering();

        buildInstruction();

        for (uint256 i; i < instruction.maxExecutions; i++) {
            user.executeInstruction(instruction, instructionSig);
            skip(1);
        }

        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.InstructionAlreadyDeactivated.selector, instructionId));

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that you can activate the same exact Instruction multiple times as long as you bump the salt
    function test_executeInstruction_bumpSalt() public {
        vm.pauseGasMetering();

        buildInstruction();

        user.executeInstruction(instruction, instructionSig);
        user.deactivateInstruction(deactivation, deactivationSig);

        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.InstructionAlreadyDeactivated.selector, instructionId));
        user.executeInstruction(instruction, instructionSig);

        buildInstruction(DEFAULT_SALT + 1, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, DEFAULT_ARGS);

        vm.expectEmit();

        emit IOtimDelegate.InstructionExecuted(instructionId, 1);

        vm.resumeGasMetering();
        user.executeInstruction(instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice typical Instruction deactivation flow
    function test_deactivateInstruction_happyPath() public {
        vm.pauseGasMetering();

        buildInstruction();

        uint256 delay = 1000;

        user.executeInstruction(instruction, instructionSig);

        executionState = instructionStorage.getExecutionState(address(user), instructionId);
        assertFalse(executionState.deactivated);
        assertEq(executionState.executionCount, 1);
        assertEq(executionState.lastExecuted, block.timestamp);

        skip(delay);

        vm.expectEmit();
        emit IOtimDelegate.InstructionDeactivated(instructionId);

        vm.resumeGasMetering();
        user.deactivateInstruction(deactivation, deactivationSig);
        vm.pauseGasMetering();

        executionState = instructionStorage.getExecutionState(address(user), instructionId);
        assertTrue(executionState.deactivated);
        assertEq(executionState.executionCount, 1);
        assertEq(executionState.lastExecuted, block.timestamp - delay);
    }

    /// @notice can't deactivate an Instruction with invalid signature
    function test_deactivateInstruction_invalidSignature() public {
        vm.pauseGasMetering();

        buildInstruction();

        user.executeInstruction(instruction, instructionSig);

        InstructionLib.Instruction memory badInstruction =
            InstructionLib.Instruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, bytes("blah"));

        InstructionLib.InstructionDeactivation memory badDeactivation =
            InstructionLib.InstructionDeactivation(_id(badInstruction));

        bytes32 badDeactivationHash = _signingHash(badDeactivation, delegate.domainSeparator());

        (uint8 b_v, bytes32 b_r, bytes32 b_s) = vm.sign(userEOA.privateKey, badDeactivationHash);
        InstructionLib.Signature memory badSignature = InstructionLib.Signature(b_v, b_r, b_s);

        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.InvalidSignature.selector, instructionId));

        vm.resumeGasMetering();
        user.deactivateInstruction(deactivation, badSignature);
        vm.pauseGasMetering();
    }

    /// @notice can't replay Instruction deactivation on a different chain
    function test_deactivateInstruction_wrongChainId() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.chainId(474747);

        OtimDelegate otherChainDelegate = new OtimDelegate(address(this));

        vm.signAndAttachDelegation(address(otherChainDelegate), userEOA.privateKey);

        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.InvalidSignature.selector, instructionId));

        vm.resumeGasMetering();
        user.deactivateInstruction(deactivation, deactivationSig);
        vm.pauseGasMetering();
    }

    /// @notice can't deactivate an already-deactivated Instruction
    function test_deactivateInstruction_alreadyDeactivated() public {
        vm.pauseGasMetering();

        buildInstruction();

        uint256 delay = 1000;

        user.executeInstruction(instruction, instructionSig);

        skip(delay);

        vm.expectEmit();
        emit IOtimDelegate.InstructionDeactivated(instructionId);

        user.deactivateInstruction(deactivation, deactivationSig);

        executionState = instructionStorage.getExecutionState(address(user), instructionId);
        assertTrue(executionState.deactivated);
        assertEq(executionState.executionCount, 1);
        assertEq(executionState.lastExecuted, block.timestamp - delay);

        vm.expectRevert(abi.encodeWithSelector(IOtimDelegate.InstructionAlreadyDeactivated.selector, instructionId));

        vm.resumeGasMetering();
        user.deactivateInstruction(deactivation, deactivationSig);
        vm.pauseGasMetering();
    }
}
