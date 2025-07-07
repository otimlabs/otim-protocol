// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";
import {VmSafe} from "forge-std/src/Vm.sol";

import {ITransferERC20Action} from "../../src/actions/interfaces/ITransferERC20Action.sol";
import {TransferERC20Action} from "../../src/actions/TransferERC20Action.sol";

contract DecodeTransferERC20 is Script {
    // command to decode TransferERC20 arguments (will be prompted for encoded arguments):
    //
    // forge script DecodeTransferERC20

    function run() public {
        bytes memory encoded = vm.parseBytes(vm.prompt("Enter encoded TransferERC20 arguments"));

        ITransferERC20Action.TransferERC20 memory decoded = abi.decode(encoded, (ITransferERC20Action.TransferERC20));

        console2.log("TransferERC20 Arguments:");
        console2.log("\t token:", decoded.token);
        console2.log("\t target:", decoded.target);
        console2.log("\t value:", decoded.value);
        console2.log("");
        console2.log("Schedule Arguments:");
        console2.log("\t schedule.startAt:", decoded.schedule.startAt);
        console2.log("\t schedule.startBy:", decoded.schedule.startBy);
        console2.log("\t schedule.interval:", decoded.schedule.interval);
        console2.log("\t schedule.timeout:", decoded.schedule.timeout);
        console2.log("");
        console2.log("Fee Arguments:");
        console2.log("\t fee.token:", decoded.fee.token);
        console2.log("\t fee.maxBaseFeePerGas:", decoded.fee.maxBaseFeePerGas);
        console2.log("\t fee.maxPriorityFeePerGas:", decoded.fee.maxPriorityFeePerGas);
        console2.log("\t fee.executionFee:", decoded.fee.executionFee);
    }
}
