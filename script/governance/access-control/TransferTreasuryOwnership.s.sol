// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script} from "forge-std/src/Script.sol";

import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";

/// @title TransferTreasuryOwnership
/// @author Otim Labs, Inc.
/// @notice script to transfer Treasury ownership to a new address
contract TransferTreasuryOwnership is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    // commands to transfer Treasury ownership to a new address (enter new owner address interactively):
    //
    // - with private key (on Anvil): forge script TransferTreasuryOwnership --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK
    // - with private key:            forge script TransferTreasuryOwnership --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK
    // - with Ledger:                 forge script TransferTreasuryOwnership --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script TransferTreasuryOwnership --broadcast --rpc-url $RPC_URL --aws

    // commands to transfer Treasury ownership to a new address (enter new owner address as a command line argument):
    //
    // - with private key (on Anvil): forge script TransferTreasuryOwnership --sig "run(address)" --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK <newOwner>
    // - with private key:            forge script TransferTreasuryOwnership --sig "run(address)" --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK <newOwner>
    // - with Ledger:                 forge script TransferTreasuryOwnership --sig "run(address)" --broadcast --rpc-url $RPC_URL --ledger <newOwner>
    // - with AWS:                    forge script TransferTreasuryOwnership --sig "run(address)" --broadcast --rpc-url $RPC_URL --aws <newOwner>

    error TreasuryAlreadyOwnedByAddress();

    function run() public {
        address newOwner = vm.promptAddress("Enter new Treasury owner address");

        run(newOwner);
    }

    function run(address newOwner) public {
        // get Treasury address from .env
        address treasuryAddress = vm.envAddress("TREASURY_ADDRESS");

        Ownable treasury = Ownable(treasuryAddress);

        if (treasury.owner() == newOwner) {
            revert TreasuryAlreadyOwnedByAddress();
        }

        vm.startBroadcast();

        // transfer Treasury ownership to new address
        treasury.transferOwnership(newOwner);

        vm.stopBroadcast();
    }
}
