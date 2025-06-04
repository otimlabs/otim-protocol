// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";
import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {ERC20Mock} from "@openzeppelin-contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink-contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";

import {OtimDelegate} from "../../src/OtimDelegate.sol";
import {InstructionStorage} from "../../src/core/InstructionStorage.sol";
import {ActionManager} from "../../src/core/ActionManager.sol";

import {FeeTokenRegistry} from "../../src/infrastructure/FeeTokenRegistry.sol";
import {Treasury} from "../../src/infrastructure/Treasury.sol";

import {TransferAction} from "../../src/actions/TransferAction.sol";
import {TransferERC20Action} from "../../src/actions/TransferERC20Action.sol";
import {RefuelAction} from "../../src/actions/RefuelAction.sol";
import {RefuelERC20Action} from "../../src/actions/RefuelERC20Action.sol";

contract AnvilDeployAll is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    /// @dev NOTE: the contract addresses created by this script depend on:
    ///     1. the deployer's address
    ///     2. the deployer's nonce
    ///
    /// In order to deploy these contracts to the same addresses each time:
    ///     1. Don't change the deployer's address
    ///     2. Don't change the order that contracts are deployed in
    ///     3. Do restart the blockchain each time so that the deployer's nonce is reset to 0

    // command to deploy to Anvil locally:
    // forge script AnvilDeployAll --broadcast --fork-url http://localhost:8545 --private-keys $ANVIL_DEPLOYER_PK --private-keys $ANVIL_OWNER_PK

    // command to deploy to hosted Anvil instance:
    // forge script AnvilDeployAll --broadcast --rpc-url $DEV_RPC_URL --private-keys $ANVIL_DEPLOYER_PK --private-keys $ANVIL_OWNER_PK

    function run() public {
        uint256 deployerPk = vm.envUint("ANVIL_DEPLOYER_PK");
        uint256 ownerPk = vm.envUint("ANVIL_OWNER_PK");

        vm.writeFile("deployment_addresses.json", "{");

        vm.writeLine(
            "deployment_addresses.json", string(abi.encodePacked("\"ChainId\":\"", vm.toString(block.chainid), "\","))
        );

        address actionManagerAddress = _deployCore(vm.addr(deployerPk), vm.addr(ownerPk));

        (address feeTokenRegistryAddress, address treasuryAddress) =
            _deployInfrastructure(vm.addr(deployerPk), vm.addr(ownerPk));

        _deployPeripheral(vm.addr(deployerPk), vm.addr(ownerPk), feeTokenRegistryAddress);

        _deployActions(
            vm.addr(deployerPk), vm.addr(ownerPk), feeTokenRegistryAddress, treasuryAddress, actionManagerAddress
        );

        vm.writeLine("deployment_addresses.json", "}");
    }

    /// @notice deploy core contracts
    function _deployCore(address deployer, address owner) private returns (address) {
        vm.broadcast(deployer);
        OtimDelegate otimDelegate = new OtimDelegate(owner);

        address actionManagerAddress = address(otimDelegate.actionManager());

        vm.writeLine(
            "deployment_addresses.json",
            string(
                abi.encodePacked(
                    "\"OtimDelegate\":\"",
                    vm.toString(address(otimDelegate)),
                    "\",",
                    "\"Gateway\":\"",
                    vm.toString(address(otimDelegate.gateway())),
                    "\",",
                    "\"InstructionStorage\":\"",
                    vm.toString(address(otimDelegate.instructionStorage())),
                    "\",",
                    "\"ActionManager\":\"",
                    vm.toString(actionManagerAddress),
                    "\","
                )
            )
        );

        return actionManagerAddress;
    }

    /// @notice deploy infrastructure contracts (fee token registry, treasury, etc.)
    function _deployInfrastructure(address deployer, address owner) private returns (address, address) {
        vm.startBroadcast(deployer);

        address feeTokenRegistryAddress = address(new FeeTokenRegistry(owner));
        address treasuryAddress = address(new Treasury(owner));

        vm.stopBroadcast();

        vm.writeLine(
            "deployment_addresses.json",
            string(
                abi.encodePacked(
                    "\"FeeTokenRegistry\":\"",
                    vm.toString(feeTokenRegistryAddress),
                    "\",",
                    "\"Treasury\":\"",
                    vm.toString(treasuryAddress),
                    "\","
                )
            )
        );

        return (feeTokenRegistryAddress, treasuryAddress);
    }

    /// @notice deploy peripheral contracts (tokens, price feeds, etc.) and add them to FeeTokenRegistry
    function _deployPeripheral(address deployer, address owner, address feeTokenRegistryAddress) private {
        vm.startBroadcast(deployer);

        address mockERC20Address = address(new ERC20Mock());
        address mockPriceFeedAddress = address(new MockV3Aggregator(18, 456392060000000));

        vm.stopBroadcast();

        // disregard heartbeat for mocks
        uint40 heartbeat = type(uint40).max;

        vm.startBroadcast(owner);

        // add MockERC20 and MockPriceFeed to FeeTokenRegistry
        FeeTokenRegistry(feeTokenRegistryAddress).addFeeToken(mockERC20Address, mockPriceFeedAddress, heartbeat);

        vm.stopBroadcast();

        vm.writeLine(
            "deployment_addresses.json",
            string(
                abi.encodePacked(
                    "\"MockERC20\":\"",
                    vm.toString(mockERC20Address),
                    "\",",
                    "\"MockPriceFeed\":\"",
                    vm.toString(mockPriceFeedAddress),
                    "\","
                )
            )
        );
    }

    /// @notice deploy actions and add them to ActionManager
    function _deployActions(
        address deployer,
        address owner,
        address feeTokenRegistryAddress,
        address treasuryAddress,
        address actionManagerAddress
    ) private {
        // deploy actions
        vm.startBroadcast(deployer);

        address transferAddress =
            address(new TransferAction(feeTokenRegistryAddress, treasuryAddress, vm.envUint("TRANSFER_GAS_CONSTANT")));
        address transferERC20Address = address(
            new TransferERC20Action(feeTokenRegistryAddress, treasuryAddress, vm.envUint("TRANSFER_ERC20_GAS_CONSTANT"))
        );
        address refuelAddress =
            address(new RefuelAction(feeTokenRegistryAddress, treasuryAddress, vm.envUint("REFUEL_GAS_CONSTANT")));
        address refuelERC20Address = address(
            new RefuelERC20Action(feeTokenRegistryAddress, treasuryAddress, vm.envUint("REFUEL_ERC20_GAS_CONSTANT"))
        );

        vm.stopBroadcast();

        // add actions to ActionManager
        ActionManager actionManager = ActionManager(actionManagerAddress);

        vm.startBroadcast(owner);

        actionManager.addAction(transferAddress);
        actionManager.addAction(transferERC20Address);
        actionManager.addAction(refuelAddress);
        actionManager.addAction(refuelERC20Address);

        vm.stopBroadcast();

        vm.writeLine(
            "deployment_addresses.json",
            string(
                abi.encodePacked(
                    "\"Transfer\":\"",
                    vm.toString(transferAddress),
                    "\",",
                    "\"TransferERC20\":\"",
                    vm.toString(transferERC20Address),
                    "\",",
                    "\"Refuel\":\"",
                    vm.toString(refuelAddress),
                    "\",",
                    "\"RefuelERC20\":\"",
                    vm.toString(refuelERC20Address),
                    "\""
                )
            )
        );
    }
}
