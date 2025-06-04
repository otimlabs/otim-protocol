// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {ECDSA} from "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {RefuelAction} from "../../src/actions/RefuelAction.sol";
import {IRefuelAction} from "../../src/actions/interfaces/IRefuelAction.sol";
import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {InstructionTestContext} from "../utils/InstructionTestContext.sol";

contract RecoverRefuel is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

    RefuelAction refuel = new RefuelAction(address(0), address(0), 0);

    address public constant account = address(0x15d733be6Cb8C3864927e977fFde109A95994c21);
    uint256 public constant pK = 0xee07cbdd41934516d0206e2e1a2692510a95c5638c03413c1fbe65a581d328f1;

    function test_recover_app_refuel() public view {
        assertEq(account, vm.addr(pK));

        IRefuelAction.Refuel memory arguments = IRefuelAction.Refuel({
            target: payable(address(1)),
            threshold: 2,
            endBalance: 3,
            gasLimit: 4,
            fee: IOtimFee.Fee({token: address(0), maxBaseFeePerGas: 6, maxPriorityFeePerGas: 7, executionFee: 8})
        });

        InstructionLib.Instruction memory instruction = InstructionLib.Instruction({
            salt: 0,
            maxExecutions: 0,
            action: address(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707),
            arguments: abi.encode(arguments)
        });

        InstructionLib.Signature memory signature = InstructionLib.Signature({
            v: 28,
            r: 0xc2b4bd0d5c42dc8228ec41955f564c6e9cc5d71ca2543d4004ec907403a15b94,
            s: 0x72fe91d713d403675d95bd8b3c46bb534282626123f2bcfe4fe27140ac341d96
        });

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
                ),
                keccak256("OtimDelegate"),
                keccak256("1"),
                11155111,
                address(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0),
                keccak256("ON_TIME_INSTRUCTED_MONEY")
            )
        );

        (bytes32 instructionTypeHash, bytes32 argumentsTypeHash) = refuel.argumentsHash(instruction.arguments);

        bytes32 signingHash = _signingHash(instruction, domainSeparator, instructionTypeHash, argumentsTypeHash);

        address recovered = ECDSA.recover(signingHash, signature.v, signature.r, signature.s);

        assertEq(account, recovered);
    }
}
