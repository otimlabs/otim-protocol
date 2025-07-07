// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";
import {VmSafe} from "forge-std/src/Vm.sol";

import {ISweepDepositAccountERC20Action} from "../../src/actions/interfaces/ISweepDepositAccountERC20Action.sol";
import {SweepDepositAccountERC20Action} from "../../src/actions/SweepDepositAccountERC20Action.sol";

contract DecodeSweepDepositAccountERC20 is Script {
    // command to decode SweepDepositAccountERC20 arguments (will be prompted for encoded arguments):
    //
    // forge script DecodeSweepDepositAccountERC20

    function run() public {
        bytes memory encoded = vm.parseBytes(vm.prompt("Enter encoded SweepDepositAccountERC20 arguments"));

        ISweepDepositAccountERC20Action.SweepDepositAccountERC20 memory decoded =
            abi.decode(encoded, (ISweepDepositAccountERC20Action.SweepDepositAccountERC20));

        console2.log("SweepDepositAccountERC20 Arguments:");
        console2.log("\t token:", decoded.token);
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
