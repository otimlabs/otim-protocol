// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";
import {VmSafe} from "forge-std/src/Vm.sol";

import {SweepSkipCCTPDepositAccountAction} from "../../../src/actions/SweepSkipCCTPDepositAccountAction.sol";

contract DeploySweepSkipCCTPDepositAccountAction is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    // command to generate the expected deployment address (without actually deploying):
    //
    // - with private key (on Anvil): forge script DeploySweepSkipCCTPDepositAccountAction --fork-url http://localhost:8545 --private-key $ANVIL_DEPLOYER_PK
    // - with private key:            forge script DeploySweepSkipCCTPDepositAccountAction --rpc-url $RPC_URL --private-key $DEPLOYER_PK
    // - with Ledger:                 forge script DeploySweepSkipCCTPDepositAccountAction --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script DeploySweepSkipCCTPDepositAccountAction --rpc-url $RPC_URL --aws

    // commands to deploy:
    //
    // - with private key (on Anvil): forge script DeploySweepSkipCCTPDepositAccountAction --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_DEPLOYER_PK
    // - with private key:            forge script DeploySweepSkipCCTPDepositAccountAction --broadcast --rpc-url $RPC_URL --private-key $DEPLOYER_PK
    // - with Ledger:                 forge script DeploySweepSkipCCTPDepositAccountAction --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script DeploySweepSkipCCTPDepositAccountAction --broadcast --rpc-url $RPC_URL --aws

    function run() public {
        address usdcAddress = vm.envAddress("USDC_ADDRESS");
        address cctpRelayerAddress = vm.envAddress("CCTP_RELAYER_ADDRESS");
        address tokenMinterAddress = vm.envAddress("TOKEN_MINTER_ADDRESS");
        address skipGoFeeOracleAddress = vm.envAddress("EXPECTED_SKIP_GO_FEE_ORACLE_ADDRESS");

        address feeTokenRegistryAddress = vm.envAddress("EXPECTED_FEE_TOKEN_REGISTRY_ADDRESS");
        address treasuryAddress = vm.envAddress("EXPECTED_TREASURY_ADDRESS");
        uint256 gasConstant = vm.envUint("SWEEP_DEPOSIT_ACCOUNT_ACTION_GAS_CONSTANT");

        vm.startBroadcast();

        SweepSkipCCTPDepositAccountAction sweepSkipCCTPDepositAccountction = new SweepSkipCCTPDepositAccountAction(
            usdcAddress,
            cctpRelayerAddress,
            tokenMinterAddress,
            skipGoFeeOracleAddress,
            feeTokenRegistryAddress,
            treasuryAddress,
            gasConstant
        );

        vm.stopBroadcast();

        console2.log("SweepSkipCCTPDepositAccountAction deployed at:", address(sweepSkipCCTPDepositAccountction));
    }
}
