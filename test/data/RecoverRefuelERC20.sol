// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {ECDSA} from "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {RefuelERC20Action} from "../../src/actions/RefuelERC20Action.sol";
import {IRefuelERC20Action} from "../../src/actions/interfaces/IRefuelERC20Action.sol";
import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {InstructionTestContext} from "../utils/InstructionTestContext.sol";

contract RecoverRefuelERC20 is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

    RefuelERC20Action refuelERC20 = new RefuelERC20Action(address(0), address(0), 0);

    address public constant account = address(0x15d733be6Cb8C3864927e977fFde109A95994c21);
    uint256 public constant pK = 0xee07cbdd41934516d0206e2e1a2692510a95c5638c03413c1fbe65a581d328f1;

    function test_recover_app_refuel_erc20() public view {
        assertEq(account, vm.addr(pK));

        IRefuelERC20Action.RefuelERC20 memory arguments = IRefuelERC20Action.RefuelERC20({
            token: address(1),
            target: address(2),
            threshold: 3,
            endBalance: 4,
            fee: IOtimFee.Fee({token: address(0), maxBaseFeePerGas: 6, maxPriorityFeePerGas: 7, executionFee: 8})
        });

        InstructionLib.Instruction memory instruction = InstructionLib.Instruction({
            salt: 0,
            maxExecutions: 0,
            action: address(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707),
            arguments: abi.encode(arguments)
        });

        InstructionLib.Signature memory signature = InstructionLib.Signature({
            v: 27,
            r: 0x93f04e036e82752b479238bb5e410a8ebddcac3d580cc046fc40b54cf07e32de,
            s: 0x1c02286dc3efd9b2467a0753988303a5955ec4fdd152ba37013f65bd97c4bfef
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

        (bytes32 instructionTypeHash, bytes32 argumentsTypeHash) = refuelERC20.argumentsHash(instruction.arguments);

        bytes32 signingHash = _signingHash(instruction, domainSeparator, instructionTypeHash, argumentsTypeHash);

        address recovered = ECDSA.recover(signingHash, signature.v, signature.r, signature.s);

        assertEq(account, recovered);
    }
}
