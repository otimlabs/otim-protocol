// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";

import {IAccessControl} from "@openzeppelin-contracts/access/IAccessControl.sol";
import {AccessControl} from "@openzeppelin-contracts/access/AccessControl.sol";

/// @title GrantKillSwitchRole
/// @author Otim Labs, Inc.
/// @notice script to grant the kill-switch role to a new address on ActionManager
contract GrantKillSwitchRole is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    // commands to grant the kill-switch role to a new address on ActionManager (enter new kill-switch owner address interactively):
    //
    // - with private key (on Anvil): forge script GrantKillSwitchRole --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK
    // - with private key:            forge script GrantKillSwitchRole --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK
    // - with Ledger:                 forge script GrantKillSwitchRole --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script GrantKillSwitchRole --broadcast --rpc-url $RPC_URL --aws

    // commands to grant the kill-switch role to a new address on ActionManager (enter new kill-switch owner address as a command line argument):
    //
    // - with private key (on Anvil): forge script GrantKillSwitchRole --sig "run(address)" --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK <newKillSwitchOwner>
    // - with private key:            forge script GrantKillSwitchRole --sig "run(address)" --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK <newKillSwitchOwner>
    // - with Ledger:                 forge script GrantKillSwitchRole --sig "run(address)" --broadcast --rpc-url $RPC_URL --ledger <newKillSwitchOwner>
    // - with AWS:                    forge script GrantKillSwitchRole --sig "run(address)" --broadcast --rpc-url $RPC_URL --aws <newKillSwitchOwner>

    bytes32 public constant KILL_SWTICH_ROLE = keccak256("KILL_SWITCH_ROLE");

    error KillSwitchRoleAlreadyGranted();

    function run() public {
        address newKillSwitchOwner = vm.promptAddress("Enter new kill-switch owner address");

        run(newKillSwitchOwner);
    }

    function run(address newKillSwitchOwner) public {
        // get ActionManager address from .env
        address actionManagerAddress = vm.envAddress("ACTION_MANAGER_ADDRESS");

        IAccessControl actionManager = IAccessControl(actionManagerAddress);

        if (actionManager.hasRole(KILL_SWTICH_ROLE, newKillSwitchOwner)) {
            revert KillSwitchRoleAlreadyGranted();
        }

        vm.startBroadcast();

        // grant kill-switch role to new address on ActionManager
        actionManager.grantRole(KILL_SWTICH_ROLE, newKillSwitchOwner);

        vm.stopBroadcast();
    }
}
