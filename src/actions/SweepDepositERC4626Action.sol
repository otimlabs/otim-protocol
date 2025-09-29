// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC4626} from "@openzeppelin-contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

import {InstructionLib} from "../libraries/Instruction.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {
    ISweepDepositERC4626Action,
    INSTRUCTION_TYPEHASH,
    ARGUMENTS_TYPEHASH
} from "./interfaces/ISweepDepositERC4626Action.sol";

import {InvalidArguments, BalanceUnderThreshold, MaxDepositZero, TotalAssetsTooLow} from "./errors/Errors.sol";

/// @title SweepDepositERC4626Action
/// @author Otim Labs, Inc.
/// @notice an Action that deposits ERC20 tokens into an ERC4626 vault
contract SweepDepositERC4626Action is IAction, ISweepDepositERC4626Action, OtimFee {
    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (SweepDepositERC4626))));
    }

    /// @inheritdoc ISweepDepositERC4626Action
    function hash(SweepDepositERC4626 memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.vault,
                arguments.recipient,
                arguments.threshold,
                arguments.endBalance,
                arguments.minTotalAssets,
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
        SweepDepositERC4626 memory arguments = abi.decode(instruction.arguments, (SweepDepositERC4626));

        // if first execution, validate the input
        if (executionState.executionCount == 0) {
            if (
                arguments.vault == address(0) || arguments.recipient == address(0)
                    || arguments.endBalance > arguments.threshold || arguments.minTotalAssets == 0
            ) {
                revert InvalidArguments();
            }
        }

        // get the underlying token
        address underlyingToken = IERC4626(arguments.vault).asset();

        // get the account's token balance
        uint256 balance = IERC20(underlyingToken).balanceOf(address(this));

        // if the balance is under the threshold or equal to the endBalance, revert.
        // the endBalance check is to prevent the instruction from executing
        // when threshold == endBalance == balance because in this case we would have depositAmount == 0
        // slither-disable-next-line incorrect-equality
        if (balance < arguments.threshold || balance == arguments.endBalance) {
            revert BalanceUnderThreshold();
        }

        // get the max deposit amount
        uint256 maxDeposit = IERC4626(arguments.vault).maxDeposit(arguments.recipient);

        // if the max deposit amount is zero, revert
        if (maxDeposit == 0) {
            revert MaxDepositZero();
        }

        // initialize deposit amount
        uint256 depositAmount = balance - arguments.endBalance;

        // if the max deposit amount is less than the deposit amount,
        // set the deposit amount to the max deposit amount and emit an event
        if (depositAmount > maxDeposit) {
            depositAmount = maxDeposit;

            emit MaxDepositReached(maxDeposit);
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
        IERC4626(arguments.vault).deposit(depositAmount, arguments.recipient);

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this action has no auto-deactivation cases
        return false;
    }
}
