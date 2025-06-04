// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";

import {ActionManager} from "../../../src/core/ActionManager.sol";

/// @title AddAction
/// @author Otim Labs, Inc.
/// @notice script to add an Action to ActionManager
contract AddAction is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    // commands to add an Action to ActionManager (enter Action address interactively):
    //
    // - with private key (on Anvil): forge script AddAction --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK
    // - with private key:            forge script AddAction --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK
    // - with ledger:                 forge script AddAction --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script AddAction --broadcast --rpc-url $RPC_URL --aws

    // commands to add an Action to ActionManager (enter Action address as a command line argument):
    //
    // - with private key (on Anvil): forge script AddAction --sig "run(address)" --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK <actionAddress>
    // - with private key:            forge script AddAction --sig "run(address)" --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK <actionAddress>
    // - with ledger:                 forge script AddAction --sig "run(address)" --broadcast --rpc-url $RPC_URL --ledger <actionAddress>
    // - with AWS:                    forge script AddAction --sig "run(address)" --broadcast --rpc-url $RPC_URL --aws <actionAddress>

    function run() public {
        address actionAddress = vm.promptAddress("Enter Action address to add to ActionManager");

        run(actionAddress);
    }

    function run(address actionAddress) public {
        // get ActionManager address from .env
        address actionManagerAddress = vm.envAddress("ACTION_MANAGER_ADDRESS");

        ActionManager actionManager = ActionManager(actionManagerAddress);

        vm.startBroadcast();

        // add action to ActionManager
        actionManager.addAction(actionAddress);

        vm.stopBroadcast();
    }
}
