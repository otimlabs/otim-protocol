// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";

import {ISkipGoFeeOracle} from "../../../src/actions/oracles/interfaces/ISkipGoFeeOracle.sol";

/// @title SetFee
/// @author Otim Labs, Inc.
/// @notice script to add a fee to SkipGoFeeOracle
contract SetFee is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    // commands to add a fee to SkipGoFeeOracle (enter parameters interactively):
    //
    // - with private key (on Anvil): forge script SetFee --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK
    // - with private key:            forge script SetFee --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK
    // - with ledger:                 forge script SetFee --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script SetFee --broadcast --rpc-url $RPC_URL --aws

    // commands to add a fee to SkipGoFeeOracle (enter parameters as command line arguments):
    //
    // - with private key (on Anvil): forge script SetFee --sig "run(uint32,uint256)" --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_OWNER_PK <destinationDomain> <fee>
    // - with private key:            forge script SetFee --sig "run(uint32,uint256)" --broadcast --rpc-url $RPC_URL --private-key $OWNER_PK <destinationDomain> <fee>
    // - with ledger:                 forge script SetFee --sig "run(uint32,uint256)" --broadcast --rpc-url $RPC_URL --ledger <destinationDomain> <fee>
    // - with AWS:                    forge script SetFee --sig "run(uint32,uint256)" --broadcast --rpc-url $RPC_URL --aws <destinationDomain> <fee>

    function run() public {
        uint32 destinationDomain = uint32(vm.promptUint("Enter destination domain for the fee"));
        uint256 fee = vm.promptUint("Enter USDC fee amount");

        run(destinationDomain, fee);
    }

    function run(uint32 destinationDomain, uint256 fee) public {
        address skipGoFeeOracleAddress = vm.envAddress("EXPECTED_SKIP_GO_FEE_ORACLE_ADDRESS");

        ISkipGoFeeOracle skipGoFeeOracle = ISkipGoFeeOracle(skipGoFeeOracleAddress);

        vm.startBroadcast();

        // add fee to SkipGoFeeOracle for the destination domain
        skipGoFeeOracle.setFee(destinationDomain, fee);

        vm.stopBroadcast();
    }
}
