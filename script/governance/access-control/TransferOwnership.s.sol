// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script} from "forge-std/src/Script.sol";

import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";

/// @title TransferOwnership
/// @author Otim Labs, Inc.
/// @notice script to transfer ownership of any Ownable contract to a new address
contract TransferOwnership is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below
    // commands to transfer ownership of an Ownable contract to a new address (enter contract and new owner addresses interactively):
    //
    // - with private key (on Anvil): forge script TransferOwnership --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK
    // - with private key:            forge script TransferOwnership --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK
    // - with Ledger:                 forge script TransferOwnership --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script TransferOwnership --broadcast --rpc-url $RPC_URL --aws

    // commands to transfer ownership of an Ownable contract to a new address (enter contract and new owner addresses as command line arguments):
    //
    // - with private key (on Anvil): forge script TransferOwnership --sig "run(address,address)" --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK <contractAddress> <newOwner>
    // - with private key:            forge script TransferOwnership --sig "run(address,address)" --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK <contractAddress> <newOwner>
    // - with Ledger:                 forge script TransferOwnership --sig "run(address,address)" --broadcast --rpc-url $RPC_URL --ledger <contractAddress> <newOwner>
    // - with AWS:                    forge script TransferOwnership --sig "run(address,address)" --broadcast --rpc-url $RPC_URL --aws <contractAddress> <newOwner>

    error ContractAlreadyOwnedByAddress();

    function run() public {
        address contractAddress = vm.promptAddress("Enter Ownable contract address");
        address newOwner = vm.promptAddress("Enter new owner address");

        run(contractAddress, newOwner);
    }

    function run(address contractAddress, address newOwner) public {
        Ownable ownableContract = Ownable(contractAddress);

        if (ownableContract.owner() == newOwner) {
            revert ContractAlreadyOwnedByAddress();
        }

        vm.startBroadcast();

        // transfer ownership to new address
        ownableContract.transferOwnership(newOwner);

        vm.stopBroadcast();
    }
}
