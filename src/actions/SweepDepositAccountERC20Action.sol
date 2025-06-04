// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Create2} from "@openzeppelin-contracts/utils/Create2.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {InstructionLib} from "../libraries/Instruction.sol";
import {AssemblyUtils} from "./libraries/AssemblyUtils.sol";

import {DepositAccount} from "./transient-contracts/DepositAccount.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";
import {CalculateDepositAddress} from "./utils/CalculateDepositAddress.sol";

import {IAction} from "./interfaces/IAction.sol";
import {
    ISweepDepositAccountERC20Action,
    INSTRUCTION_TYPEHASH,
    ARGUMENTS_TYPEHASH
} from "./interfaces/ISweepDepositAccountERC20Action.sol";

import {InvalidArguments, BalanceUnderThreshold} from "./errors/Errors.sol";

/// @title SweepDepositAccountERC20Action
/// @author Otim Labs, Inc.
/// @notice an Action that sweeps ERC20 tokens from a deposit account when the balance is above a threshold
contract SweepDepositAccountERC20Action is
    IAction,
    ISweepDepositAccountERC20Action,
    OtimFee,
    CalculateDepositAddress
{
    using InstructionLib for InstructionLib.Instruction;

    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (SweepDepositAccountERC20))));
    }

    /// @inheritdoc ISweepDepositAccountERC20Action
    function hash(SweepDepositAccountERC20 memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.token,
                arguments.depositor,
                arguments.recipient,
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
        SweepDepositAccountERC20 memory arguments = abi.decode(instruction.arguments, (SweepDepositAccountERC20));

        // check that the arguments are valid on first execution
        if (executionState.executionCount == 0) {
            if (arguments.token == address(0) || arguments.depositor == address(0) || arguments.recipient == address(0))
            {
                revert InvalidArguments();
            }
        }

        // calculate the deposit account address
        address depositAccountAddress = calculateDepositAddress(address(this), arguments.depositor);

        // if the deposit account token balance is less than the threshold, revert
        if (IERC20(arguments.token).balanceOf(depositAccountAddress) <= arguments.threshold) {
            revert BalanceUnderThreshold();
        }

        // deploy the deposit account if it doesn't already exist
        if (depositAccountAddress.code.length == 0) {
            new DepositAccount{salt: keccak256(abi.encode(SALT_PREFIX, arguments.depositor))}();
        }

        // save the deposit account ETH balance before sweeping
        uint256 startEthBalance = depositAccountAddress.balance;

        // sweep the deposit account
        DepositAccount(payable(depositAccountAddress)).sweep(arguments.token, arguments.recipient);

        // if the deposit account had ETH to begin with, refund it
        if (startEthBalance > 0) {
            // slither-disable-next-line unused-return
            AssemblyUtils.safeTransferNoReturn(depositAccountAddress, startEthBalance, 0);
        }

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this action has no auto-deactivation logic
        return false;
    }
}
