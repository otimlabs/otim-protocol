// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";
import {VmSafe} from "forge-std/src/Vm.sol";

import {CrossRatePriceFeed} from "../../../src/infrastructure/CrossRatePriceFeed.sol";

contract DeployCrossRatePriceFeed is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below
    // command to run the script without actually deploying:
    //
    // forge script DeployCrossRatePriceFeed

    // commands to deploy:
    //
    // - with private key (on Anvil): forge script DeployCrossRatePriceFeed --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_DEPLOYER_PK
    // - with private key:            forge script DeployCrossRatePriceFeed --broadcast --rpc-url $RPC_URL --private-key $DEPLOYER_PK
    // - with Ledger:                 forge script DeployCrossRatePriceFeed --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script DeployCrossRatePriceFeed --broadcast --rpc-url $RPC_URL --aws

    error ExpectedAddressMismatch();

    function run() public {
        address numeratorPriceFeed = vm.envAddress("NUMERATOR_PRICE_FEED_ADDRESS");
        address denominatorPriceFeed = vm.envAddress("DENOMINATOR_PRICE_FEED_ADDRESS");
        uint40 numeratorHeartbeat = uint40(vm.envUint("NUMERATOR_HEARTBEAT"));
        uint40 denominatorHeartbeat = uint40(vm.envUint("DENOMINATOR_HEARTBEAT"));

        vm.startBroadcast();

        // deploy CrossRatePriceFeed contract
        CrossRatePriceFeed crossRatePriceFeed =
            new CrossRatePriceFeed(numeratorPriceFeed, denominatorPriceFeed, numeratorHeartbeat, denominatorHeartbeat);

        vm.stopBroadcast();

        console2.log("CrossRatePriceFeed deployed at:", address(crossRatePriceFeed));
    }
}
