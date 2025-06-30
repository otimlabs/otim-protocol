// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";

import {ISkipGoFeeOracle} from "../../../src/actions/oracles/interfaces/ISkipGoFeeOracle.sol";

/// @title RemoveFee
/// @author Otim Labs, Inc.
/// @notice script to remove a fee from SkipGoFeeOracle
contract RemoveFee is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    // commands to remove a fee from SkipGoFeeOracle (enter parameters interactively):
    //
    // - with private key (on Anvil): forge script RemoveFee --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK
    // - with private key:            forge script RemoveFee --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK
    // - with ledger:                 forge script RemoveFee --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script RemoveFee --broadcast --rpc-url $RPC_URL --aws

    // commands to remove a fee from SkipGoFeeOracle (enter parameters as command line arguments):
    //
    // - with private key (on Anvil): forge script RemoveFee --sig "run(uint32)" --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK <destinationDomain>
    // - with private key:            forge script RemoveFee --sig "run(uint32)" --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK <destinationDomain>
    // - with ledger:                 forge script RemoveFee --sig "run(uint32)" --broadcast --rpc-url $RPC_URL --ledger <destinationDomain>
    // - with AWS:                    forge script RemoveFee --sig "run(uint32)" --broadcast --rpc-url $RPC_URL --aws <destinationDomain>

    function run() public {
        uint32 destinationDomain = uint32(vm.promptUint("Enter destination domain for the fee"));

        run(destinationDomain);
    }

    function run(uint32 destinationDomain) public {
        address skipGoFeeOracleAddress = vm.envAddress("EXPECTED_SKIP_GO_FEE_ORACLE_ADDRESS");

        ISkipGoFeeOracle skipGoFeeOracle = ISkipGoFeeOracle(skipGoFeeOracleAddress);

        vm.startBroadcast();

        // remove fee from SkipGoFeeOracle for the destination domain
        skipGoFeeOracle.removeFee(destinationDomain);

        vm.stopBroadcast();
    }
}
