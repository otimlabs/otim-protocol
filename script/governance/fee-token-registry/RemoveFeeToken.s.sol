// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";

import {FeeTokenRegistry} from "../../../src/infrastructure/FeeTokenRegistry.sol";

/// @title RemoveFeeToken
/// @author Otim Labs, Inc.
/// @notice script to remove a fee token from FeeTokenRegistry
contract RemoveFeeToken is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    // commands to remove a fee token from FeeTokenRegistry (enter parameters interactively):
    //
    // - with private key (on Anvil): forge script RemoveFeeToken --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK
    // - with private key:            forge script RemoveFeeToken --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK
    // - with ledger:                 forge script RemoveFeeToken --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script RemoveFeeToken --broadcast --rpc-url $RPC_URL --aws

    // commands to remove a fee token from FeeTokenRegistry (enter parameters as command line arguments):
    //
    // - with private key (on Anvil): forge script RemoveFeeToken --sig "run(address)" --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK <tokenAddress>
    // - with private key:            forge script RemoveFeeToken --sig "run(address)" --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK <tokenAddress>
    // - with ledger:                 forge script RemoveFeeToken --sig "run(address)" --broadcast --rpc-url $RPC_URL --ledger <tokenAddress>
    // - with AWS:                    forge script RemoveFeeToken --sig "run(address)" --broadcast --rpc-url $RPC_URL --aws <tokenAddress>

    function run() public {
        address tokenAddress = vm.promptAddress("Enter token address to remove from FeeTokenRegistry");

        run(tokenAddress);
    }

    function run(address tokenAddress) public {
        address feeTokenRegistryAddress = vm.envAddress("FEE_TOKEN_REGISTRY_ADDRESS");

        FeeTokenRegistry feeTokenRegistry = FeeTokenRegistry(feeTokenRegistryAddress);

        vm.startBroadcast();

        // remove fee token from FeeTokenRegistry
        feeTokenRegistry.removeFeeToken(tokenAddress);

        vm.stopBroadcast();
    }
}
