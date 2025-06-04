// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";
import {VmSafe} from "forge-std/src/Vm.sol";

import {UniswapV3ExactInputAction} from "../../../src/actions/UniswapV3ExactInputAction.sol";

contract DeployUniswapV3ExactInputAction is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    // command to generate the expected deployment address (without actually deploying):
    //
    // - with private key (on Anvil): forge script DeployUniswapV3ExactInputAction --fork-url http://localhost:8545 --private-key $ANVIL_DEPLOYER_PK
    // - with private key:            forge script DeployUniswapV3ExactInputAction --rpc-url $RPC_URL --private-key $DEPLOYER_PK
    // - with Ledger:                 forge script DeployUniswapV3ExactInputAction --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script DeployUniswapV3ExactInputAction --rpc-url $RPC_URL --aws

    // commands to deploy:
    //
    // - with private key (on Anvil): forge script DeployUniswapV3ExactInputAction --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_DEPLOYER_PK
    // - with private key:            forge script DeployUniswapV3ExactInputAction --broadcast --rpc-url $RPC_URL --private-key $DEPLOYER_PK
    // - with Ledger:                 forge script DeployUniswapV3ExactInputAction --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script DeployUniswapV3ExactInputAction --broadcast --rpc-url $RPC_URL --aws

    function run() public {
        address universalRouterAddress = vm.envAddress("UNIVERSAL_ROUTER_ADDRESS");
        address uniswapV3FactoryAddress = vm.envAddress("UNISWAP_V3_FACTORY_ADDRESS");
        address weth9Address = vm.envAddress("WETH9_ADDRESS");
        address feeTokenRegistryAddress = vm.envAddress("EXPECTED_FEE_TOKEN_REGISTRY_ADDRESS");
        address treasuryAddress = vm.envAddress("EXPECTED_TREASURY_ADDRESS");
        uint256 gasConstant = vm.envUint("UNISWAP_V3_EXACT_INPUT_ACTION_GAS_CONSTANT");

        vm.startBroadcast();

        UniswapV3ExactInputAction uniswapV3ExactInputAction = new UniswapV3ExactInputAction(
            universalRouterAddress,
            uniswapV3FactoryAddress,
            weth9Address,
            feeTokenRegistryAddress,
            treasuryAddress,
            gasConstant
        );

        vm.stopBroadcast();

        console2.log("UniswapV3ExactInputAction deployed at:", address(uniswapV3ExactInputAction));
    }
}
