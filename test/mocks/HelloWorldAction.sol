// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IAction} from "../../src/actions/interfaces/IAction.sol";
import {InstructionLib} from "../../src/libraries/Instruction.sol";

/// @notice a dummy Action contract for testing
contract HelloWorldAction is IAction {
    bytes32 constant INSTRUCTION_TYPEHASH = keccak256(
        "Instruction(uint256 salt,uint256 maxExecutions,address action,HelloWorld helloWorld)HelloWorld(string message,uint256 favoriteNumber)"
    );

    bytes32 constant ARGUMENTS_TYPEHASH = keccak256("HelloWorld(string message,uint256 favoriteNumber)");

    struct HelloWorld {
        string message;
        uint256 favoriteNumber;
    }

    event EmitHelloWorld();

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) external pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (HelloWorld))));
    }

    function hash(HelloWorld memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(ARGUMENTS_TYPEHASH, keccak256(abi.encode(arguments.message)), arguments.favoriteNumber)
        );
    }

    function execute(
        InstructionLib.Instruction calldata instruction,
        InstructionLib.Signature calldata,
        InstructionLib.ExecutionState calldata
    ) external override returns (bool deactivate) {
        HelloWorld memory helloWorld = abi.decode(instruction.arguments, (HelloWorld));

        if (helloWorld.favoriteNumber == 47) {
            _emitHelloWorld();
        } else {
            _badFunction();
        }

        return false;
    }

    function _emitHelloWorld() internal {
        emit EmitHelloWorld();
    }

    function _badFunction() internal pure {
        revert();
    }
}
