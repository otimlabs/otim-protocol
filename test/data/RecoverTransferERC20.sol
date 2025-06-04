// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {ECDSA} from "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";

import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {TransferERC20Action} from "../../src/actions/TransferERC20Action.sol";
import {ITransferERC20Action} from "../../src/actions/interfaces/ITransferERC20Action.sol";

import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";
import {IInterval} from "../../src/actions/schedules/interfaces/IInterval.sol";

import {InstructionTestContext} from "../utils/InstructionTestContext.sol";

contract RecoverTransferERC20 is InstructionTestContext {
    using InstructionLib for InstructionLib.Instruction;

    TransferERC20Action transferERC20 = new TransferERC20Action(address(0), address(0), 0);

    address public constant account = address(0x15d733be6Cb8C3864927e977fFde109A95994c21);
    uint256 public constant pK = 0xee07cbdd41934516d0206e2e1a2692510a95c5638c03413c1fbe65a581d328f1;

    function test_recover_app_transfer_erc20() public view {
        assertEq(account, vm.addr(pK));

        ITransferERC20Action.TransferERC20 memory arguments = ITransferERC20Action.TransferERC20({
            token: address(1),
            target: address(2),
            value: 3,
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
            v: 27,
            r: 0xa44b11757face17e123f4c090074820145e596df4962dc6e2e7d90917d8cdafd,
            s: 0x552ed3349fb759799a04a26688d823899d88f2c3cf49eb7036870b9625d092dd
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

        (bytes32 instructionTypeHash, bytes32 argumentsTypeHash) = transferERC20.argumentsHash(instruction.arguments);

        bytes32 signingHash = _signingHash(instruction, domainSeparator, instructionTypeHash, argumentsTypeHash);

        address recovered = ECDSA.recover(signingHash, signature.v, signature.r, signature.s);

        assertEq(account, recovered);
    }
}
