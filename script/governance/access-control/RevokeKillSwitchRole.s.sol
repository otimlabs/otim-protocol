// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";

import {IAccessControl} from "@openzeppelin-contracts/access/IAccessControl.sol";
import {AccessControl} from "@openzeppelin-contracts/access/AccessControl.sol";

/// @title RevokeKillSwitchRole
/// @author Otim Labs, Inc.
/// @notice script to revoke the kill-switch role from an address on ActionManager
contract RevokeKillSwitchRole is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    // commands to revoke the kill-switch role from an address on ActionManager (enter old kill-switch owner address interactively):
    //
    // - with private key (on Anvil): forge script RevokeKillSwitchRole --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK
    // - with private key:            forge script RevokeKillSwitchRole --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK
    // - with Ledger:                 forge script RevokeKillSwitchRole --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script RevokeKillSwitchRole --broadcast --rpc-url $RPC_URL --aws

    // commands to revoke the kill-switch role from an address on ActionManager (enter old kill-switch owner address as a command line argument):
    //
    // - with private key (on Anvil): forge script RevokeKillSwitchRole --sig "run(address)" --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK <oldKillSwitchOwner>
    // - with private key:            forge script RevokeKillSwitchRole --sig "run(address)" --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK <oldKillSwitchOwner>
    // - with Ledger:                 forge script RevokeKillSwitchRole --sig "run(address)" --broadcast --rpc-url $RPC_URL --ledger <oldKillSwitchOwner>
    // - with AWS:                    forge script RevokeKillSwitchRole --sig "run(address)" --broadcast --rpc-url $RPC_URL --aws <oldKillSwitchOwner>

    bytes32 public constant KILL_SWTICH_ROLE = keccak256("KILL_SWITCH_ROLE");

    error KillSwitchRoleAlreadyRevoked();

    function run() public {
        address oldKillSwitchOwner = vm.promptAddress("Enter old kill-switch owner address");

        run(oldKillSwitchOwner);
    }

    function run(address oldKillSwitchOwner) public {
        // get ActionManager address from .env
        address actionManagerAddress = vm.envAddress("ACTION_MANAGER_ADDRESS");

        IAccessControl actionManager = IAccessControl(actionManagerAddress);

        if (!actionManager.hasRole(KILL_SWTICH_ROLE, oldKillSwitchOwner)) {
            revert KillSwitchRoleAlreadyRevoked();
        }

        vm.startBroadcast();

        // revoke kill-switch role from address on ActionManager
        actionManager.revokeRole(KILL_SWTICH_ROLE, oldKillSwitchOwner);

        vm.stopBroadcast();
    }
}
