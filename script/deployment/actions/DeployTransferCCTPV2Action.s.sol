// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";
import {VmSafe} from "forge-std/src/Vm.sol";

import {TransferCCTPV2Action} from "../../../src/actions/TransferCCTPV2Action.sol";

contract DeployTransferCCTPV2Action is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below
    // commands to deploy:
    //
    // - with private key (on Anvil): forge script DeployTransferCCTPV2Action --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_DEPLOYER_PK
    // - with private key:            forge script DeployTransferCCTPV2Action --broadcast --rpc-url $RPC_URL --private-key $DEPLOYER_PK
    // - with Ledger:                 forge script DeployTransferCCTPV2Action --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script DeployTransferCCTPV2Action --broadcast --rpc-url $RPC_URL --aws

    function run() public {
        address tokenMessengerV2Address = vm.envAddress("CCTP_V2_TOKEN_MESSENGER_ADDRESS");
        address tokenMinterAddress = vm.envAddress("CCTP_V2_TOKEN_MINTER_ADDRESS");
        address feeTokenRegistryAddress = vm.envAddress("EXPECTED_FEE_TOKEN_REGISTRY_ADDRESS");
        address treasuryAddress = vm.envAddress("EXPECTED_TREASURY_ADDRESS");
        uint256 gasConstant = vm.envUint("TRANSFER_CCTP_V2_ACTION_GAS_CONSTANT");

        vm.startBroadcast();

        // deploy TransferCCTPV2Action
        TransferCCTPV2Action transferCCTPV2Action = new TransferCCTPV2Action(
            tokenMessengerV2Address, tokenMinterAddress, feeTokenRegistryAddress, treasuryAddress, gasConstant
        );

        vm.stopBroadcast();

        console2.log("TransferCCTPV2Action deployed at:", address(transferCCTPV2Action));
    }
}

