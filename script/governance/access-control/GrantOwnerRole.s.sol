// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";

import {IAccessControl} from "@openzeppelin-contracts/access/IAccessControl.sol";
import {AccessControl} from "@openzeppelin-contracts/access/AccessControl.sol";

/// @title GrantOwnerRole
/// @author Otim Labs, Inc.
/// @notice script to grant the owner role to a new address on ActionManager
contract GrantOwnerRole is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    // commands to grant the owner role to a new address on ActionManager (enter new owner address interactively):
    //
    // - with private key (on Anvil): forge script GrantOwnerRole --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK
    // - with private key:            forge script GrantOwnerRole --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK
    // - with Ledger:                 forge script GrantOwnerRole --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script GrantOwnerRole --broadcast --rpc-url $RPC_URL --aws

    // commands to grant the owner role to a new address on ActionManager (enter new owner address as a command line argument):
    //
    // - with private key (on Anvil): forge script GrantOwnerRole --sig "run(address)" --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK <newOwner>
    // - with private key:            forge script GrantOwnerRole --sig "run(address)" --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK <newOwner>
    // - with Ledger:                 forge script GrantOwnerRole --sig "run(address)" --broadcast --rpc-url $RPC_URL --ledger <newOwner>
    // - with AWS:                    forge script GrantOwnerRole --sig "run(address)" --broadcast --rpc-url $RPC_URL --aws <newOwner>

    /// @dev this is the same as the DEFAULT_ADMIN_ROLE in OpenZeppelin's AccessControl.sol
    bytes32 public constant OWNER_ROLE = 0x00;

    error OwnerRoleAlreadyGranted();

    function run() public {
        address newOwner = vm.promptAddress("Enter new owner address");

        run(newOwner);
    }

    function run(address newOwner) public {
        // get ActionManager address from .env
        address actionManagerAddress = vm.envAddress("ACTION_MANAGER_ADDRESS");

        IAccessControl actionManager = IAccessControl(actionManagerAddress);

        if (actionManager.hasRole(OWNER_ROLE, newOwner)) {
            revert OwnerRoleAlreadyGranted();
        }

        vm.startBroadcast();

        // grant owner role to new address on ActionManager
        actionManager.grantRole(OWNER_ROLE, newOwner);

        vm.stopBroadcast();
    }
}
