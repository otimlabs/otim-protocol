// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";

import {IAccessControl} from "@openzeppelin-contracts/access/IAccessControl.sol";
import {AccessControl} from "@openzeppelin-contracts/access/AccessControl.sol";

/// @title RevokeOwnerRole
/// @author Otim Labs, Inc.
/// @notice script to revoke the owner role from an address on ActionManager
contract RevokeOwnerRole is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    // commands to revoke the owner role from an address on ActionManager (enter old owner address interactively):
    //
    // - with private key (on Anvil): forge script RevokeOwnerRole --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK
    // - with private key:            forge script RevokeOwnerRole --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK
    // - with Ledger:                 forge script RevokeOwnerRole --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script RevokeOwnerRole --broadcast --rpc-url $RPC_URL --aws

    // commands to revoke the owner role from an address on ActionManager (enter old owner address as a command line argument):
    //
    // - with private key (on Anvil): forge script RevokeOwnerRole --sig "run(address)" --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK <oldOwner>
    // - with private key:            forge script RevokeOwnerRole --sig "run(address)" --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK <oldOwner>
    // - with Ledger:                 forge script RevokeOwnerRole --sig "run(address)" --broadcast --rpc-url $RPC_URL --ledger <oldOwner>
    // - with AWS:                    forge script RevokeOwnerRole --sig "run(address)" --broadcast --rpc-url $RPC_URL --aws <oldOwner>

    /// @dev this is the same as the DEFAULT_ADMIN_ROLE in OpenZeppelin's AccessControl.sol
    bytes32 public constant OWNER_ROLE = 0x00;

    error OwnerRoleAlreadyRevoked();
    error NoSelfRevoke();

    function run() public {
        address oldOwner = vm.promptAddress("Enter old owner address");

        run(oldOwner);
    }

    function run(address oldOwner) public {
        // get ActionManager address from .env
        address actionManagerAddress = vm.envAddress("ACTION_MANAGER_ADDRESS");

        IAccessControl actionManager = IAccessControl(actionManagerAddress);

        if (!actionManager.hasRole(OWNER_ROLE, oldOwner)) {
            revert OwnerRoleAlreadyRevoked();
        }

        // This is to prevent the current owner from revoking themselves.
        // In the case that the current owner is the only owner,
        // they should not be able to revoke themselves because all root access would be lost forever.
        if (msg.sender == oldOwner) {
            revert NoSelfRevoke();
        }

        vm.startBroadcast();

        // revoke owner role from address on ActionManager
        actionManager.revokeRole(OWNER_ROLE, oldOwner);

        vm.stopBroadcast();
    }
}
