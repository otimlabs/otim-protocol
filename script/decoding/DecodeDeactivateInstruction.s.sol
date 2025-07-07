// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";
import {VmSafe} from "forge-std/src/Vm.sol";

import {IDeactivateInstructionAction} from "../../src/actions/interfaces/IDeactivateInstructionAction.sol";
import {DeactivateInstructionAction} from "../../src/actions/DeactivateInstructionAction.sol";

contract DecodeDeactivateInstruction is Script {
    // command to decode DeactivateInstruction arguments (will be prompted for encoded arguments):
    //
    // forge script DecodeDeactivateInstruction

    function run() public {
        bytes memory encoded = vm.parseBytes(vm.prompt("Enter encoded DeactivateInstruction arguments"));

        IDeactivateInstructionAction.DeactivateInstruction memory decoded =
            abi.decode(encoded, (IDeactivateInstructionAction.DeactivateInstruction));

        console2.log("DeactivateInstruction Arguments:");
        console2.log("\t instructionId:", vm.toString(decoded.instructionId));
        console2.log("");
        console2.log("Fee Arguments:");
        console2.log("\t fee.token:", decoded.fee.token);
        console2.log("\t fee.maxBaseFeePerGas:", decoded.fee.maxBaseFeePerGas);
        console2.log("\t fee.maxPriorityFeePerGas:", decoded.fee.maxPriorityFeePerGas);
        console2.log("\t fee.executionFee:", decoded.fee.executionFee);
    }
}
