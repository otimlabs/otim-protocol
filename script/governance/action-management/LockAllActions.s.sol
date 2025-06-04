// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";

import {ActionManager} from "../../../src/core/ActionManager.sol";

/// @title LockAllActions
/// @author Otim Labs, Inc.
/// @notice script to lock all actions on ActionManager
contract LockAllActions is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    // commands to lock all actions on ActionManager:
    //
    // - with private key (on Anvil): forge script LockAllActions --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK
    // - with private key:            forge script LockAllActions --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK
    // - with ledger:                 forge script LockAllActions --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script LockAllActions --broadcast --rpc-url $RPC_URL --aws

    function run() public {
        // get ActionManager address from .env
        address actionManagerAddress = vm.envAddress("ACTION_MANAGER_ADDRESS");

        ActionManager actionManager = ActionManager(actionManagerAddress);

        vm.startBroadcast();

        // engage global lock on ActionManager
        actionManager.lockAllActions();

        vm.stopBroadcast();
    }
}
