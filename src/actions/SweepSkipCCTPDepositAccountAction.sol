// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {InstructionLib} from "../libraries/Instruction.sol";

import {SkipCCTPDepositAccount} from "./transient-contracts/SkipCCTPDepositAccount.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";
import {CalculateSkipCCTPDepositAddress} from "./utils/CalculateSkipCCTPDepositAddress.sol";

import {IAction} from "./interfaces/IAction.sol";
import {
    ISweepSkipCCTPDepositAccountAction,
    INSTRUCTION_TYPEHASH,
    ARGUMENTS_TYPEHASH
} from "./interfaces/ISweepSkipCCTPDepositAccountAction.sol";

import {InvalidArguments} from "./errors/Errors.sol";

/// @title SweepSkipCCTPDepositAccountAction
/// @author Otim Labs, Inc.
/// @notice an Action that sweeps USDC from a SkipCCTPDepositAccount to the Skip Go CCTP relayer contract
contract SweepSkipCCTPDepositAccountAction is
    IAction,
    ISweepSkipCCTPDepositAccountAction,
    OtimFee,
    CalculateSkipCCTPDepositAddress
{
    using InstructionLib for InstructionLib.Instruction;

    constructor(
        address usdcAddress_,
        address cctpRelayerAddress_,
        address tokenMinterAddress_,
        address skipGoFeeOracleAddress_,
        address feeTokenRegistryAddress,
        address treasuryAddress,
        uint256 gasConstant_
    )
        CalculateSkipCCTPDepositAddress(usdcAddress_, cctpRelayerAddress_, tokenMinterAddress_, skipGoFeeOracleAddress_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (SweepSkipCCTPDepositAccount))));
    }

    /// @inheritdoc ISweepSkipCCTPDepositAccountAction
    function hash(SweepSkipCCTPDepositAccount memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.depositor,
                arguments.destinationDomain,
                arguments.destinationMintRecipient,
                arguments.threshold,
                hash(arguments.fee)
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
        SweepSkipCCTPDepositAccount memory arguments = abi.decode(instruction.arguments, (SweepSkipCCTPDepositAccount));

        // check that the arguments are valid on first execution
        if (executionState.executionCount == 0) {
            if (arguments.depositor == address(0) || arguments.destinationMintRecipient == bytes32(0)) {
                revert InvalidArguments();
            }
        }

        // slither-disable-next-line uninitialized-local
        address depositAccountAddress;

        // try to deploy a new SkipCCTPDepositAccount contract using Create2
        // if the contract already exists, it will revert, and we will just use the existing address
        try new SkipCCTPDepositAccount{salt: SALT}(
            usdcAddress,
            cctpRelayerAddress,
            tokenMinterAddress,
            skipGoFeeOracleAddress,
            arguments.depositor,
            arguments.destinationDomain,
            arguments.destinationMintRecipient
        ) returns (SkipCCTPDepositAccount depositAccount) {
            depositAccountAddress = address(depositAccount);
        } catch {
            // if the contract already exists, we calculate its address
            depositAccountAddress = calculateDepositAddress(
                address(this), arguments.depositor, arguments.destinationDomain, arguments.destinationMintRecipient
            );
        }

        // sweep USDC from the SkipCCTPDepositAccount to the Skip Go CCTP relayer contract
        SkipCCTPDepositAccount(depositAccountAddress).sweep(arguments.threshold);

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this action has no auto-deactivation logic
        return false;
    }
}
