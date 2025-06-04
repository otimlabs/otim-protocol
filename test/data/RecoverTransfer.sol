// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {ECDSA} from "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {TransferAction} from "../../src/actions/TransferAction.sol";
import {ITransferAction} from "../../src/actions/interfaces/ITransferAction.sol";
import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";
import {IInterval} from "../../src/actions/schedules/interfaces/IInterval.sol";

import {InstructionTestContext} from "../utils/InstructionTestContext.sol";

contract RecoverTransfer is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

    TransferAction transfer = new TransferAction(address(0), address(0), 0);

    address public constant account = address(0x15d733be6Cb8C3864927e977fFde109A95994c21);
    uint256 public constant pK = 0xee07cbdd41934516d0206e2e1a2692510a95c5638c03413c1fbe65a581d328f1;

    function test_recover_app_transfer() public view {
        assertEq(account, vm.addr(pK));

        ITransferAction.Transfer memory arguments = ITransferAction.Transfer({
            target: payable(address(1)),
            value: 2,
            gasLimit: 3,
            schedule: IInterval.Schedule({startAt: 4, startBy: 5, interval: 6, timeout: 7}),
            fee: IOtimFee.Fee({token: address(0), maxBaseFeePerGas: 9, maxPriorityFeePerGas: 10, executionFee: 11})
        });

        InstructionLib.Instruction memory instruction = InstructionLib.Instruction({
            salt: 0,
            maxExecutions: 0,
            action: address(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707),
            arguments: abi.encode(arguments)
        });

        InstructionLib.Signature memory signature = InstructionLib.Signature({
            v: 28,
            r: 0xeb0ca911609a0f491f0367f711c677c445de62d9a7808f7f72250587dd3e5be9,
            s: 0x201407ce12d781d5d397dd9b21e2d8fad6ba088c21db8f88728cb3c1fbef1ad9
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

        (bytes32 instructionTypeHash, bytes32 argumentsTypeHash) = transfer.argumentsHash(instruction.arguments);

        bytes32 signingHash = _signingHash(instruction, domainSeparator, instructionTypeHash, argumentsTypeHash);

        address recovered = ECDSA.recover(signingHash, signature.v, signature.r, signature.s);

        assertEq(account, recovered);
    }
}
