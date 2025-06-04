// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Create2} from "@openzeppelin-contracts/utils/Create2.sol";

import {InstructionLib} from "../libraries/Instruction.sol";

import {DepositAccount} from "./transient-contracts/DepositAccount.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";
import {CalculateDepositAddress} from "./utils/CalculateDepositAddress.sol";

import {IAction} from "./interfaces/IAction.sol";
import {
    ISweepDepositAccountAction,
    INSTRUCTION_TYPEHASH,
    ARGUMENTS_TYPEHASH
} from "./interfaces/ISweepDepositAccountAction.sol";

import {InvalidArguments, BalanceUnderThreshold} from "./errors/Errors.sol";

/// @title SweepDepositAccountAction
/// @author Otim Labs, Inc.
/// @notice an Action that sweeps ether from a deposit account when the balance is above a threshold
contract SweepDepositAccountAction is IAction, ISweepDepositAccountAction, OtimFee, CalculateDepositAddress {
    using InstructionLib for InstructionLib.Instruction;

    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (SweepDepositAccount))));
    }

    /// @inheritdoc ISweepDepositAccountAction
    function hash(SweepDepositAccount memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH, arguments.depositor, arguments.recipient, arguments.threshold, hash(arguments.fee)
            )
        );
    }

    /// @inheritdoc IAction
    function execute(
        InstructionLib.Instruction calldata instruction,
        InstructionLib.Signature calldata,
        InstructionLib.ExecutionState calldata executionState
    ) external override returns (bool) {
        // initial gas measurement for fee calculation
        uint256 startGas = gasleft();

        // decode the arguments from the instruction
        SweepDepositAccount memory arguments = abi.decode(instruction.arguments, (SweepDepositAccount));

        // check that the arguments are valid on first execution
        if (executionState.executionCount == 0) {
            if (arguments.depositor == address(0) || arguments.recipient == address(0)) {
                revert InvalidArguments();
            }
        }

        // calculate the deposit account address
        address depositAccountAddress = calculateDepositAddress(address(this), arguments.depositor);

        // if the deposit account balance is less than the threshold, revert
        if (depositAccountAddress.balance <= arguments.threshold) {
            revert BalanceUnderThreshold();
        }

        // deploy the deposit account if it doesn't already exist
        if (depositAccountAddress.code.length == 0) {
            new DepositAccount{salt: keccak256(abi.encode(SALT_PREFIX, arguments.depositor))}();
        }

        // sweep the deposit account balance to the recipient and selfdestruct the deposit account
        DepositAccount(payable(depositAccountAddress)).sweep(arguments.recipient);

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this action has no auto-deactivation logic
        return false;
    }
}
