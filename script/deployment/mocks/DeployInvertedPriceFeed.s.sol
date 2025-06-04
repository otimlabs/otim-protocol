// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";
import {VmSafe} from "forge-std/src/Vm.sol";

import {InvertedPriceFeed} from "../../../src/mocks/InvertedPriceFeed.sol";

contract DeployInvertedPriceFeed is Script {
    // command to run the script without actually deploying:
    //
    // forge script DeployInvertedPriceFeed

    // commands to deploy:
    //
    // - with private key (on Anvil): forge script DeployInvertedPriceFeed --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_DEPLOYER_PK
    // - with private key:            forge script DeployInvertedPriceFeed --broadcast --rpc-url $RPC_URL --private-key $DEPLOYER_PK
    // - with Ledger:                 forge script DeployInvertedPriceFeed --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script DeployInvertedPriceFeed --broadcast --rpc-url $RPC_URL --aws

    function run() public {
        address priceFeedAddress = vm.envAddress("PRICE_FEED_TO_INVERT_ADDRESS");

        vm.startBroadcast();

        InvertedPriceFeed invertedPriceFeed = new InvertedPriceFeed(priceFeedAddress);

        vm.stopBroadcast();

        console2.log("Inverted Price Feed deployed at:", address(invertedPriceFeed));
        console2.log("Original Price Feed address:", priceFeedAddress);
    }
}
