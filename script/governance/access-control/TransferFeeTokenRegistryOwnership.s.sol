// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script} from "forge-std/src/Script.sol";

import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";

/// @title TransferFeeTokenRegistryOwnership
/// @author Otim Labs, Inc.
/// @notice script to transfer FeeTokenRegistry ownership to a new address
contract TransferFeeTokenRegistryOwnership is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    // commands to transfer FeeTokenRegistry ownership to a new address (enter new owner address interactively):
    //
    // - with private key (on Anvil): forge script TransferFeeTokenRegistryOwnership --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK
    // - with private key:            forge script TransferFeeTokenRegistryOwnership --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK
    // - with Ledger:                 forge script TransferFeeTokenRegistryOwnership --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script TransferFeeTokenRegistryOwnership --broadcast --rpc-url $RPC_URL --aws

    // commands to transfer FeeTokenRegistry ownership to a new address (enter new owner address as a command line argument):
    //
    // - with private key (on Anvil): forge script TransferFeeTokenRegistryOwnership --sig "run(address)" --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK <newOwner>
    // - with private key:            forge script TransferFeeTokenRegistryOwnership --sig "run(address)" --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK <newOwner>
    // - with Ledger:                 forge script TransferFeeTokenRegistryOwnership --sig "run(address)" --broadcast --rpc-url $RPC_URL --ledger <newOwner>
    // - with AWS:                    forge script TransferFeeTokenRegistryOwnership --sig "run(address)" --broadcast --rpc-url $RPC_URL --aws <newOwner>

    error FeeTokenRegistryAlreadyOwnedByAddress();

    function run() public {
        address newOwner = vm.promptAddress("Enter new FeeTokenRegistry owner address");

        run(newOwner);
    }

    function run(address newOwner) public {
        // get FeeTokenRegistry address from .env
        address feeTokenRegistryAddress = vm.envAddress("FEE_TOKEN_REGISTRY_ADDRESS");

        Ownable feeTokenRegistry = Ownable(feeTokenRegistryAddress);

        if (feeTokenRegistry.owner() == newOwner) {
            revert FeeTokenRegistryAlreadyOwnedByAddress();
        }

        vm.startBroadcast();

        // transfer FeeTokenRegistry ownership to new address
        feeTokenRegistry.transferOwnership(newOwner);

        vm.stopBroadcast();
    }
}
