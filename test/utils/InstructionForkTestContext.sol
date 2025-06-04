// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/src/Test.sol";
import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {Constants} from "../../src/libraries/Constants.sol";
import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {OtimDelegate} from "../../src/OtimDelegate.sol";
import {Gateway} from "../../src/core/Gateway.sol";
import {InstructionStorage} from "../../src/core/InstructionStorage.sol";
import {ActionManager} from "../../src/core/ActionManager.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";
import {IAction} from "../../src/actions/interfaces/IAction.sol";

abstract contract InstructionForkTestContext is Test {
    using InstructionLib for InstructionLib.Instruction;
    using InstructionLib for InstructionLib.InstructionDeactivation;

    /// @notice test Core contracts
    OtimDelegate public delegate = new OtimDelegate(address(this));

    Gateway public gateway = Gateway(address(delegate.gateway()));
    InstructionStorage public instructionStorage = InstructionStorage(address(delegate.instructionStorage()));
    ActionManager public actionManager = ActionManager(address(delegate.actionManager()));

    /// @notice user EOA
    VmSafe.Wallet public userEOA = vm.createWallet("userEOA");

    /// @notice delegated user
    IOtimDelegate public user = IOtimDelegate(userEOA.addr);

    uint256 public USER_START_BALANCE = 1 ether;

    /// @notice reusable Instruction vars
    InstructionLib.Instruction public instruction;
    bytes32 public instructionId;
    bytes32 public instructionHash;
    InstructionLib.Signature public instructionSig;

    /// @notice reusable signature vars
    InstructionLib.InstructionDeactivation public deactivation;
    bytes32 public deactivationHash;
    InstructionLib.Signature public deactivationSig;

    /// @notice default Instruction values
    uint256 public DEFAULT_SALT;
    uint256 public DEFAULT_MAX_EXECUTIONS;
    address public DEFAULT_ACTION;
    bytes public DEFAULT_ARGS;

    function setUp() public virtual {
        /// @notice delegate user to OtimDelegate
        vm.signAndAttachDelegation(address(delegate), userEOA.privateKey);

        /// @notice deal some Ether to user and target
        vm.deal(address(user), USER_START_BALANCE);
    }

    /// @notice build an Instruction and save it in state vars for use
    function buildInstruction(uint256 salt_, uint256 maxExecutions_, address action_, bytes memory args_) public {
        InstructionLib.Instruction memory _instruction =
            InstructionLib.Instruction(salt_, maxExecutions_, action_, args_);

        instruction = _instruction;

        instructionId = _id(_instruction);

        (bytes32 instructionTypeHash, bytes32 argumentsHash) = IAction(action_).argumentsHash(args_);

        instructionHash = _signingHash(_instruction, delegate.domainSeparator(), instructionTypeHash, argumentsHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userEOA.privateKey, instructionHash);
        instructionSig = InstructionLib.Signature(v, r, s);

        InstructionLib.InstructionDeactivation memory _deactivation =
            InstructionLib.InstructionDeactivation(instructionId);

        deactivation = _deactivation;

        deactivationHash = _signingHash(_deactivation, delegate.domainSeparator());
        (uint8 dv, bytes32 dr, bytes32 ds) = vm.sign(userEOA.privateKey, deactivationHash);
        deactivationSig = InstructionLib.Signature(dv, dr, ds);
    }

    /// @notice build default Instruction
    function buildInstruction() public {
        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, DEFAULT_ARGS);
    }

    /// @notice build an Instruction and save it in state vars for use
    function returnInstruction(uint256 salt_, uint256 maxExecutions_, address action_, bytes memory args_)
        public
        pure
        returns (InstructionLib.Instruction memory _instruction)
    {
        _instruction = InstructionLib.Instruction(salt_, maxExecutions_, action_, args_);
    }

    /// @notice build default Instruction
    function returnInstruction() public view returns (InstructionLib.Instruction memory) {
        return returnInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, DEFAULT_ARGS);
    }

    function _id(InstructionLib.Instruction memory _instruction) public pure returns (bytes32) {
        return keccak256(abi.encode(_instruction));
    }

    function _signingHash(
        InstructionLib.Instruction memory _instruction,
        bytes32 domainSeparator,
        bytes32 instructionTypeHash,
        bytes32 argumentsHash
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                Constants.EIP712_PREFIX,
                domainSeparator,
                keccak256(
                    abi.encode(
                        instructionTypeHash,
                        _instruction.salt,
                        _instruction.maxExecutions,
                        _instruction.action,
                        argumentsHash
                    )
                )
            )
        );
    }

    function _signingHash(InstructionLib.InstructionDeactivation memory _deactivation, bytes32 domainSeparator)
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                Constants.EIP712_PREFIX,
                domainSeparator,
                keccak256(abi.encode(InstructionLib.DEACTIVATION_TYPEHASH, _deactivation.instructionId))
            )
        );
    }
}
