// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";
import {VmSafe} from "forge-std/src/Vm.sol";

import {IUniswapV3ExactInputAction} from "../../../src/actions/interfaces/IUniswapV3ExactInputAction.sol";
import {UniswapV3ExactInputAction} from "../../../src/actions/UniswapV3ExactInputAction.sol";

contract DecodeUniswapV3ExactInput is Script {
    // command to decode UniswapV3ExactInput arguments (will be prompted for encoded arguments):
    //
    // forge script DecodeUniswapV3ExactInput

    function run() public {
        bytes memory encoded = vm.parseBytes(vm.prompt("Enter encoded UniswapV3ExactInput arguments"));

        IUniswapV3ExactInputAction.UniswapV3ExactInput memory decoded =
            abi.decode(encoded, (IUniswapV3ExactInputAction.UniswapV3ExactInput));

        console2.log("UniswapV3ExactInput Arguments:");
        console2.log("\t recipient:", decoded.recipient);
        console2.log("\t tokenIn:", decoded.tokenIn);
        console2.log("\t tokenOut:", decoded.tokenOut);
        console2.log("\t feeTier:", decoded.feeTier);
        console2.log("\t amountIn:", decoded.amountIn);
        console2.log("\t floorAmountOut:", decoded.floorAmountOut);
        console2.log("\t meanPriceLookBack:", decoded.meanPriceLookBack);
        console2.log("\t maxPriceDeviationBPS:", decoded.maxPriceDeviationBPS);
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
