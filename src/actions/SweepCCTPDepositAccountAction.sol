// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Create2} from "@openzeppelin-contracts/utils/Create2.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

import {InstructionLib} from "../libraries/Instruction.sol";
import {AssemblyUtils} from "./libraries/AssemblyUtils.sol";

import {ITokenController} from "./external/ITokenController.sol";

import {CCTPDepositAccount} from "./transient-contracts/CCTPDepositAccount.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";
import {CalculateCCTPDepositAddress} from "./utils/CalculateCCTPDepositAddress.sol";

import {IAction} from "./interfaces/IAction.sol";
import {
    ISweepCCTPDepositAccountAction,
    INSTRUCTION_TYPEHASH,
    ARGUMENTS_TYPEHASH
} from "./interfaces/ISweepCCTPDepositAccountAction.sol";

import {InvalidArguments, BalanceUnderThreshold} from "./errors/Errors.sol";

/// @title SweepCCTPDepositAccountAction
/// @author Otim Labs, Inc.
/// @notice an Action that sweeps ERC20 tokens from a CCTPDepositAccount to the CCTP TokenMessenger
contract SweepCCTPDepositAccountAction is
    IAction,
    ISweepCCTPDepositAccountAction,
    OtimFee,
    CalculateCCTPDepositAddress
{
    using InstructionLib for InstructionLib.Instruction;

    ITokenController public immutable tokenMinter;

    constructor(
        address tokenMessengerAddress,
        address tokenMinterAddress,
        address feeTokenRegistryAddress,
        address treasuryAddress,
        uint256 gasConstant_
    )
        CalculateCCTPDepositAddress(tokenMessengerAddress)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {
        tokenMinter = ITokenController(tokenMinterAddress);
    }

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (SweepCCTPDepositAccount))));
    }

    /// @inheritdoc ISweepCCTPDepositAccountAction
    function hash(SweepCCTPDepositAccount memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.token,
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
        SweepCCTPDepositAccount memory arguments = abi.decode(instruction.arguments, (SweepCCTPDepositAccount));

        // check that the arguments are valid on first execution
        if (executionState.executionCount == 0) {
            if (
                arguments.token == address(0) || arguments.depositor == address(0)
                    || arguments.destinationMintRecipient == bytes32(0)
            ) {
                revert InvalidArguments();
            }
        }

        // calculate the CCTPDepositAccount address
        address cctpDepositAccountAddress = calculateCCTPDepositAddress(address(this), arguments.depositor);

        // if the deposit account token balance is less than the threshold, revert
        if (IERC20(arguments.token).balanceOf(cctpDepositAccountAddress) <= arguments.threshold) {
            revert BalanceUnderThreshold();
        }

        // deploy the CCTPDepositAccount if it doesn't already exist
        if (cctpDepositAccountAddress.code.length == 0) {
            new CCTPDepositAccount{salt: keccak256(abi.encode(SALT_PREFIX, arguments.depositor))}(
                address(tokenMessenger)
            );
        }

        // save the deposit account ETH balance before sweeping
        uint256 startEthBalance = cctpDepositAccountAddress.balance;

        // get max burn amount per message for the token
        uint256 maxBurnPerMessage = tokenMinter.burnLimitsPerMessage(arguments.token);

        // sweep the CCTPDepositAccount ERC20 tokens to the CCTP TokenMessenger
        CCTPDepositAccount(payable(cctpDepositAccountAddress)).sweepToCCTP(
            arguments.token, arguments.destinationDomain, arguments.destinationMintRecipient, maxBurnPerMessage
        );

        // if the CCTPDepositAccount had ETH to begin with, refund it
        if (startEthBalance > 0) {
            // slither-disable-next-line unused-return
            AssemblyUtils.safeTransferNoReturn(cctpDepositAccountAddress, startEthBalance, 0);
        }

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this action has no auto-deactivation logic
        return false;
    }
}
