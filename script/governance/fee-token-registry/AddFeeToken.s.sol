// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";

import {FeeTokenRegistry} from "../../../src/infrastructure/FeeTokenRegistry.sol";

/// @title AddFeeToken
/// @author Otim Labs, Inc.
/// @notice script to add a fee token to FeeTokenRegistry
contract AddFeeToken is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    // commands to add a fee token to FeeTokenRegistry (enter parameters interactively):
    //
    // - with private key (on Anvil): forge script AddFeeToken --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK
    // - with private key:            forge script AddFeeToken --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK
    // - with ledger:                 forge script AddFeeToken --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script AddFeeToken --broadcast --rpc-url $RPC_URL --aws

    // commands to add a fee token to FeeTokenRegistry (enter parameters as command line arguments):
    //
    // - with private key (on Anvil): forge script AddFeeToken --sig "run(address,address,uint40)" --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK <tokenAddress> <priceFeedAddress> <heartbeat>
    // - with private key:            forge script AddFeeToken --sig "run(address,address,uint40)" --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK <tokenAddress> <priceFeedAddress> <heartbeat>
    // - with ledger:                 forge script AddFeeToken --sig "run(address,address,uint40)" --broadcast --rpc-url $RPC_URL --ledger <tokenAddress> <priceFeedAddress> <heartbeat>
    // - with AWS:                    forge script AddFeeToken --sig "run(address,address,uint40)" --broadcast --rpc-url $RPC_URL --aws <tokenAddress> <priceFeedAddress> <heartbeat>

    function run() public {
        address tokenAddress = vm.promptAddress("Enter token address to add to FeeTokenRegistry");
        address priceFeedAddress = vm.promptAddress("Enter price feed address for the token");
        uint40 heartbeat = uint40(vm.promptUint("Enter price feed heartbeat in seconds"));

        run(tokenAddress, priceFeedAddress, heartbeat);
    }

    function run(address tokenAddress, address priceFeedAddress, uint40 heartbeat) public {
        address feeTokenRegistryAddress = vm.envAddress("FEE_TOKEN_REGISTRY_ADDRESS");

        FeeTokenRegistry feeTokenRegistry = FeeTokenRegistry(feeTokenRegistryAddress);

        vm.startBroadcast();

        // add fee token to FeeTokenRegistry
        feeTokenRegistry.addFeeToken(tokenAddress, priceFeedAddress, heartbeat);

        vm.stopBroadcast();
    }
}
