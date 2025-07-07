// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";
import {VmSafe} from "forge-std/src/Vm.sol";

import {IRefuelERC20Action} from "../../../src/actions/interfaces/IRefuelERC20Action.sol";
import {RefuelERC20Action} from "../../../src/actions/RefuelERC20Action.sol";

contract DecodeRefuelERC20 is Script {
    // command to decode RefuelERC20 arguments (will be prompted for encoded arguments):
    //
    // forge script DecodeRefuelERC20

    function run() public {
        bytes memory encoded = vm.parseBytes(vm.prompt("Enter encoded RefuelERC20 arguments"));

        IRefuelERC20Action.RefuelERC20 memory decoded = abi.decode(encoded, (IRefuelERC20Action.RefuelERC20));

        console2.log("RefuelERC20 Arguments:");
        console2.log("\t token:", decoded.token);
        console2.log("\t target:", decoded.target);
        console2.log("\t threshold:", decoded.threshold);
        console2.log("\t endBalance:", decoded.endBalance);
        console2.log("");
        console2.log("Fee Arguments:");
        console2.log("\t fee.token:", decoded.fee.token);
        console2.log("\t fee.maxBaseFeePerGas:", decoded.fee.maxBaseFeePerGas);
        console2.log("\t fee.maxPriorityFeePerGas:", decoded.fee.maxPriorityFeePerGas);
        console2.log("\t fee.executionFee:", decoded.fee.executionFee);
    }
}
