// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";
import {VmSafe} from "forge-std/src/Vm.sol";

import {ISweepSkipCCTPDepositAccountAction} from "../../src/actions/interfaces/ISweepSkipCCTPDepositAccountAction.sol";
import {SweepSkipCCTPDepositAccountAction} from "../../src/actions/SweepSkipCCTPDepositAccountAction.sol";

contract DecodeSweepSkipCCTPDepositAccount is Script {
    // command to decode SweepSkipCCTPDepositAccount arguments (will be prompted for encoded arguments):
    //
    // forge script DecodeSweepSkipCCTPDepositAccount

    function run() public {
        bytes memory encoded = vm.parseBytes(vm.prompt("Enter encoded SweepSkipCCTPDepositAccount arguments"));

        ISweepSkipCCTPDepositAccountAction.SweepSkipCCTPDepositAccount memory decoded =
            abi.decode(encoded, (ISweepSkipCCTPDepositAccountAction.SweepSkipCCTPDepositAccount));

        console2.log("SweepSkipCCTPDepositAccount Arguments:");
        console2.log("\t depositor:", decoded.depositor);
        console2.log("\t destinationDomain:", decoded.destinationDomain);
        console2.log("\t destinationMintRecipient:", vm.toString(decoded.destinationMintRecipient));
        console2.log("\t threshold:", decoded.threshold);
        console2.log("");
        console2.log("Fee Arguments:");
        console2.log("\t fee.token:", decoded.fee.token);
        console2.log("\t fee.maxBaseFeePerGas:", decoded.fee.maxBaseFeePerGas);
        console2.log("\t fee.maxPriorityFeePerGas:", decoded.fee.maxPriorityFeePerGas);
        console2.log("\t fee.executionFee:", decoded.fee.executionFee);
    }
}
