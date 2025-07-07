// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";
import {VmSafe} from "forge-std/src/Vm.sol";

import {ISweepDepositAccountAction} from "../../../src/actions/interfaces/ISweepDepositAccountAction.sol";
import {SweepDepositAccountAction} from "../../../src/actions/SweepDepositAccountAction.sol";

contract DecodeSweepDepositAccount is Script {
    // command to decode SweepDepositAccount arguments (will be prompted for encoded arguments):
    //
    // forge script DecodeSweepDepositAccount

    function run() public {
        bytes memory encoded = vm.parseBytes(vm.prompt("Enter encoded SweepDepositAccount arguments"));

        ISweepDepositAccountAction.SweepDepositAccount memory decoded =
            abi.decode(encoded, (ISweepDepositAccountAction.SweepDepositAccount));

        console2.log("SweepDepositAccount Arguments:");
        console2.log("\t depositor:", decoded.depositor);
        console2.log("\t recipient:", decoded.recipient);
        console2.log("\t threshold:", decoded.threshold);
        console2.log("");
        console2.log("Fee Arguments:");
        console2.log("\t fee.token:", decoded.fee.token);
        console2.log("\t fee.maxBaseFeePerGas:", decoded.fee.maxBaseFeePerGas);
        console2.log("\t fee.maxPriorityFeePerGas:", decoded.fee.maxPriorityFeePerGas);
        console2.log("\t fee.executionFee:", decoded.fee.executionFee);
    }
}
