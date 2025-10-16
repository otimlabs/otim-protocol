// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";

import {SweepUniswapV3Action} from "../../../src/actions/SweepUniswapV3Action.sol";

contract DeploySweepUniswapV3Action is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below
    // commands to deploy:
    //
    // - with private key (on Anvil): forge script DeploySweepUniswapV3Action --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_DEPLOYER_PK
    // - with private key:            forge script DeploySweepUniswapV3Action --broadcast --rpc-url $RPC_URL --private-key $DEPLOYER_PK
    // - with Ledger:                 forge script DeploySweepUniswapV3Action --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script DeploySweepUniswapV3Action --broadcast --rpc-url $RPC_URL --aws

    function run() public {
        address universalRouterAddress = vm.envAddress("UNIVERSAL_ROUTER_ADDRESS");
        address uniswapV3FactoryAddress = vm.envAddress("UNISWAP_V3_FACTORY_ADDRESS");
        address weth9Address = vm.envAddress("WETH9_ADDRESS");
        address feeTokenRegistryAddress = vm.envAddress("EXPECTED_FEE_TOKEN_REGISTRY_ADDRESS");
        address treasuryAddress = vm.envAddress("EXPECTED_TREASURY_ADDRESS");
        uint256 gasConstant = vm.envUint("SWEEP_UNISWAP_V3_ACTION_GAS_CONSTANT");

        vm.startBroadcast();

        SweepUniswapV3Action sweepUniswapV3Action = new SweepUniswapV3Action(
            universalRouterAddress,
            uniswapV3FactoryAddress,
            weth9Address,
            feeTokenRegistryAddress,
            treasuryAddress,
            gasConstant
        );

        vm.stopBroadcast();

        console2.log("SweepUniswapV3Action deployed at:", address(sweepUniswapV3Action));
    }
}
