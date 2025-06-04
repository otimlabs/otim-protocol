// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

// dependencies
import {IERC165} from "@openzeppelin-contracts/utils/introspection/IERC165.sol";
import {IERC1271} from "@openzeppelin-contracts/interfaces/IERC1271.sol";
import {ReentrancyGuardTransient} from "@openzeppelin-contracts/utils/ReentrancyGuardTransient.sol";
import {ECDSA} from "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";

// receiver abstract contract
import {Receiver} from "./context/Receiver.sol";

// libraries
import {InstructionLib} from "./libraries/Instruction.sol";

// core contracts
import {Gateway} from "./core/Gateway.sol";
import {InstructionStorage} from "./core/InstructionStorage.sol";
import {ActionManager} from "./core/ActionManager.sol";

// core interfaces
import {IGateway} from "./core/interfaces/IGateway.sol";
import {IInstructionStorage} from "./core/interfaces/IInstructionStorage.sol";
import {IActionManager} from "./core/interfaces/IActionManager.sol";
import {IAction} from "./actions/interfaces/IAction.sol";
import {IOtimDelegate} from "./IOtimDelegate.sol";

/// @title OtimDelegate
/// @author Otim Labs, Inc.
/// @notice the EIP-7702 delegate contract for the Otim protocol
contract OtimDelegate is IOtimDelegate, Receiver, ReentrancyGuardTransient {
    using InstructionLib for InstructionLib.Instruction;
    using InstructionLib for InstructionLib.InstructionDeactivation;

    /// @notice a helper contract for checking user delegation status
    IGateway public immutable gateway;

    /// @notice a helper contract for storing user Instruction execution state
    IInstructionStorage public immutable instructionStorage;
    /// @notice a helper contract for managing access to Actions
    IActionManager public immutable actionManager;

    /// @notice the EIP-712 domain separator for OtimDelegate
    bytes32 public immutable domainSeparator;

    constructor(address owner) {
        gateway = new Gateway();

        instructionStorage = new InstructionStorage();
        actionManager = new ActionManager(owner);

        domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
                ),
                keccak256("OtimDelegate"),
                keccak256("1"),
                block.chainid,
                address(this),
                keccak256("ON_TIME_INSTRUCTED_MONEY")
            )
        );
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165, Receiver) returns (bool) {
        return super.supportsInterface(interfaceId) || interfaceId == type(IERC1271).interfaceId
            || interfaceId == type(IOtimDelegate).interfaceId;
    }

    /// @inheritdoc IERC1271
    function isValidSignature(bytes32 hash, bytes memory signature) public view returns (bytes4) {
        // try to recover the signer from the hash and signature
        // slither-disable-next-line unused-return
        (address signer,,) = ECDSA.tryRecover(hash, signature);

        // return the selector if the signer is the current EOA
        return signer == address(this) ? this.isValidSignature.selector : bytes4(0);
    }

    /// @inheritdoc IOtimDelegate
    function executeInstruction(
        InstructionLib.Instruction calldata instruction,
        InstructionLib.Signature calldata signature
    ) external nonReentrant {
        // calculate the unique identifier for this Instruction
        bytes32 instructionId = instruction.id();

        // read execution state from external storage using the unique identifier
        InstructionLib.ExecutionState memory executionState = instructionStorage.getExecutionState(instructionId);

        // revert if the Instruction has already been deactivated
        if (executionState.deactivated) revert InstructionAlreadyDeactivated(instructionId);

        // revert if the Action contract is not executable
        bool executable = actionManager.isExecutable(instruction.action);
        if (!executable) revert ActionNotExecutable(instructionId);

        // if this is the first execution, carry out validation checks
        if (executionState.executionCount == 0) {
            // call the Action contract to return EIP-712 Instruction type and arguments hash
            (bytes32 instructionTypeHash, bytes32 argumentsHash) =
                IAction(instruction.action).argumentsHash(instruction.arguments);

            // calculate the signing hash for the Instruction
            bytes32 signingHash = instruction.signingHash(domainSeparator, instructionTypeHash, argumentsHash);

            // recover the signer from the signing hash and signature
            // slither-disable-next-line unused-return
            (address signer,,) = ECDSA.tryRecover(signingHash, signature.v, signature.r, signature.s);

            // revert if the signer is not the current EOA
            if (signer != address(this)) revert InvalidSignature(instructionId);
        }

        // ensures that the Instruction is not executed twice in the same block
        if (block.timestamp <= executionState.lastExecuted) {
            revert ExecutionSameBlock(instructionId);
        }

        // execute the Action contract
        // slither-disable-start controlled-delegatecall
        // slither-disable-next-line reentrancy-events
        (bool success, bytes memory executionResult) = instruction.action.delegatecall(
            abi.encodeWithSelector(IAction.execute.selector, instruction, signature, executionState)
        );
        // slither-disable-end controlled-delegatecall

        // revert if the Action contract execution reverted
        if (!success) revert ActionExecutionFailed(instructionId, executionResult);

        // if the Action succeeds but returns deactivate = true, this means the Instruction should be automatically deactivated
        if (abi.decode(executionResult, (bool))) {
            // deactivate the Instruction, don't increment executionCount or update lastExecuted
            instructionStorage.deactivateStorage(instructionId);

            // emit that the Instruction was deactivated
            emit InstructionDeactivated(instructionId);

            return;
        } else if (++executionState.executionCount == instruction.maxExecutions) {
            // if this is the Instruction's final successful execution, increment executionCount and deactivate
            instructionStorage.incrementAndDeactivate(instructionId);
        } else {
            // if this is not the final successful execution, just increment the executionCount
            instructionStorage.incrementExecutionCounter(instructionId);
        }

        // emit that the Instruction was executed successfully
        emit InstructionExecuted(instructionId, executionState.executionCount);
    }

    /// @inheritdoc IOtimDelegate
    function deactivateInstruction(
        InstructionLib.InstructionDeactivation calldata deactivation,
        InstructionLib.Signature calldata signature
    ) external {
        // read deactivation status from external storage, revert if already deactivated
        bool deactivated = instructionStorage.isDeactivated(deactivation.instructionId);
        if (deactivated) revert InstructionAlreadyDeactivated(deactivation.instructionId);

        // calculate deactivation signing hash
        bytes32 signingHash = deactivation.signingHash(domainSeparator);

        // recover the signer from the signing hash and signature
        // slither-disable-next-line unused-return
        (address signer,,) = ECDSA.tryRecover(signingHash, signature.v, signature.r, signature.s);

        // revert if the signer is not the current EOA
        if (signer != address(this)) revert InvalidSignature(deactivation.instructionId);

        // deactivate the Instruction in external storage
        // slither-disable-next-line reentrancy-events
        instructionStorage.deactivateStorage(deactivation.instructionId);

        // emit that the Instruction was deactivated successfully
        emit InstructionDeactivated(deactivation.instructionId);
    }
}
