// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";
import {VmSafe} from "forge-std/src/Vm.sol";

import {IRefuelAction} from "../../../src/actions/interfaces/IRefuelAction.sol";
import {RefuelAction} from "../../../src/actions/RefuelAction.sol";

contract DecodeRefuel is Script {
    // command to decode Refuel arguments (will be prompted for encoded arguments):
    //
    // forge script DecodeRefuel

    function run() public {
        bytes memory encoded = vm.parseBytes(vm.prompt("Enter encoded Refuel arguments"));

        IRefuelAction.Refuel memory decoded = abi.decode(encoded, (IRefuelAction.Refuel));

        console2.log("Refuel Arguments:");
        console2.log("\t target:", decoded.target);
        console2.log("\t threshold:", decoded.threshold);
        console2.log("\t endBalance:", decoded.endBalance);
        console2.log("\t gasLimit:", decoded.gasLimit);
        console2.log("");
        console2.log("Fee Arguments:");
        console2.log("\t fee.token:", decoded.fee.token);
        console2.log("\t fee.maxBaseFeePerGas:", decoded.fee.maxBaseFeePerGas);
        console2.log("\t fee.maxPriorityFeePerGas:", decoded.fee.maxPriorityFeePerGas);
        console2.log("\t fee.executionFee:", decoded.fee.executionFee);
    }
}
