// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/src/Script.sol";
import {VmSafe} from "forge-std/src/Vm.sol";

import {SweepDepositAccountAction} from "../../../src/actions/SweepDepositAccountAction.sol";

contract DeploySweepDepositAccountAction is Script {
    /// @dev make sure to run `cp .env_example .env` and fill in each variable
    /// then run `source .env` in your terminal before copying and pasting one of the commands below

    /// @dev this script will deploy to the same address on every chain.
    /// this deterministic address depend on a few things:
    /// - the owner address
    /// - the salt
    /// - the creation code of the contract
    ///     - **** the number of optimizer_runs will change the creation code (see foundry.toml) ****
    ///     - **** the version of the Solidity compiler will change the creation code ****
    ///     - **** the EVM version (cancun, prague, etc) will change the creation code ****
    ///     - **** dependency versions can change the creation code ****
    ///     - **** the forge version can change the creation code ****
    ///     - **** compiler flags (--via-ir, --overwrite, etc) can change the creation code ****
    /// - the address of the deployer (this won't change because we are using the cannoical Create2 factory 0x4e59b44847b379578588920ca78fbf26c0b4956c, but good to know)
    ///
    ///
    /// if any of these values change, the addresses will change, so we must be careful to keep these values constant.
    /// in order to help with this, a check is added here to ensure that the calculated address matches the expected address
    /// before deploying. if the addresses do not match, the script will revert.

    // command to generate the expected deployment address (without actually deploying):
    //
    // forge script DeploySweepDepositAccountAction

    // commands to deterministically deploy (and check the expected address before deploying):
    //
    // - with private key (on Anvil): forge script DeploySweepDepositAccountAction --broadcast --fork-url http://localhost:8545 --private-key $ANVIL_DEPLOYER_PK
    // - with private key:            forge script DeploySweepDepositAccountAction --broadcast --rpc-url $RPC_URL --private-key $DEPLOYER_PK
    // - with Ledger:                 forge script DeploySweepDepositAccountAction --broadcast --rpc-url $RPC_URL --ledger
    // - with AWS:                    forge script DeploySweepDepositAccountAction --broadcast --rpc-url $RPC_URL --aws

    bytes32 constant salt = keccak256("ON_TIME_INSTRUCTED_MONEY");

    error ExpectedAddressMismatch();

    function run() public {
        address feeTokenRegistryAddress = vm.envAddress("EXPECTED_FEE_TOKEN_REGISTRY_ADDRESS");
        address treasuryAddress = vm.envAddress("EXPECTED_TREASURY_ADDRESS");
        uint256 gasConstant = vm.envUint("SWEEP_DEPOSIT_ACCOUNT_ACTION_GAS_CONSTANT");

        // if this isn't a dry-run (aka we're using `--broadcast`), make sure to check the expected address
        if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
            checkExpectedAddress(feeTokenRegistryAddress, treasuryAddress, gasConstant);
        }

        vm.startBroadcast();

        // deterministically deploy SweepDepositAccountAction contract via canonical Create2 deployer
        SweepDepositAccountAction sweepDepositAction =
            new SweepDepositAccountAction{salt: salt}(feeTokenRegistryAddress, treasuryAddress, gasConstant);

        vm.stopBroadcast();

        console2.log("SweepDepositAccountAction deployed at:", address(sweepDepositAction));
    }

    function checkExpectedAddress(address feeTokenRegistry, address treasuryAddress, uint256 gasConstant) public view {
        /// @dev before deploying for the first time, generate this expected address by running this script in dry-run mode (see above).
        /// once it has been deployed for the first time, that deployed address should be used as the expected address from then on.
        address expectedAddress = vm.envAddress("EXPECTED_SWEEP_DEPOSIT_ACCOUNT_ACTION_ADDRESS");

        // calculate the expected address using the current init code
        address calculatedAddress = vm.computeCreate2Address(
            salt,
            keccak256(
                abi.encodePacked(
                    type(SweepDepositAccountAction).creationCode,
                    abi.encode(feeTokenRegistry, treasuryAddress, gasConstant)
                )
            )
        );

        // revert if the expected address does not match the calculated address
        if (expectedAddress != calculatedAddress) {
            revert ExpectedAddressMismatch();
        }
    }
}
