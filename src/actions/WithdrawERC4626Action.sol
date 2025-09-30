// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC4626} from "@openzeppelin-contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {InstructionLib} from "../libraries/Instruction.sol";

import {Interval} from "./schedules/Interval.sol";
import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {
    IWithdrawERC4626Action, INSTRUCTION_TYPEHASH, ARGUMENTS_TYPEHASH
} from "./interfaces/IWithdrawERC4626Action.sol";

import {InvalidArguments, InsufficientBalance, TotalAssetsTooLow} from "./errors/Errors.sol";

/// @title DepositERC4626Action
/// @author Otim Labs, Inc.
/// @notice an Action that deposits ERC20 tokens into an ERC4626 vault
contract WithdrawERC4626Action is IAction, IWithdrawERC4626Action, Interval, OtimFee {
    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (WithdrawERC4626))));
    }

    /// @inheritdoc IWithdrawERC4626Action
    function hash(WithdrawERC4626 memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.vault,
                arguments.value,
                arguments.minTotalAssets,
                hash(arguments.schedule),
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
        WithdrawERC4626 memory arguments = abi.decode(instruction.arguments, (WithdrawERC4626));

        // if first execution, validate the input
        if (executionState.executionCount == 0) {
            if (arguments.vault == address(0) || arguments.value == 0 || arguments.minTotalAssets == 0) {
                revert InvalidArguments();
            }

            checkStart(arguments.schedule);
        } else {
            checkInterval(arguments.schedule, executionState.lastExecuted);
        }

        // get the underlying token
        address underlyingToken = IERC4626(arguments.vault).asset();

        // get the max withdraw amount
        uint256 maxWithdraw = IERC4626(arguments.vault).maxWithdraw(address(this));

        // initialize deposit amount
        uint256 withdrawAmount = arguments.value;

        // if the max deposit amount is less than the deposit amount,
        // set the deposit amount to the max deposit amount and emit an event
        if (withdrawAmount > maxWithdraw) {
            withdrawAmount = maxWithdraw;

            emit MaxWithdrawReached(maxWithdraw);
        }

        // check if the account has enough balance to deposit
        if (IERC20(underlyingToken).balanceOf(address(this)) < depositAmount) {
            revert InsufficientBalance();
        }

        // check if vault total assets is too low
        if (IERC4626(arguments.vault).totalAssets() < arguments.minTotalAssets) {
            revert TotalAssetsTooLow();
        }

        // approve the deposit amount to the vault
        // slither-disable-next-line unused-return
        IERC20(underlyingToken).approve(arguments.vault, depositAmount);

        // deposit the deposit amount into the vault
        // slither-disable-next-line unused-return
        IERC4626(arguments.vault).deposit(depositAmount, address(this));

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this action has no auto-deactivation cases
        return false;
    }
}
