// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {InstructionLib} from "../libraries/Instruction.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {ISweepERC20Action, INSTRUCTION_TYPEHASH, ARGUMENTS_TYPEHASH} from "./interfaces/ISweepERC20Action.sol";

import {InvalidArguments, BalanceUnderThreshold} from "./errors/Errors.sol";

/// @title SweepERC20Action
/// @author Otim Labs, Inc.
/// @notice an Action that sweeps ERC20 tokens from the user's account to a target when the balance is greater than or equal to a threshold
contract SweepERC20Action is IAction, ISweepERC20Action, OtimFee {
    using InstructionLib for InstructionLib.Instruction;
    using SafeERC20 for IERC20;

    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (SweepERC20))));
    }

    /// @inheritdoc ISweepERC20Action
    function hash(SweepERC20 memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.token,
                arguments.target,
                arguments.threshold,
                arguments.endBalance,
                hash(arguments.fee)
            )
        );
    }

    /// @inheritdoc IAction
    function execute(
        InstructionLib.Instruction calldata instruction,
        InstructionLib.Signature calldata,
        InstructionLib.ExecutionState calldata executionState
    ) external override returns (bool deactivate) {
        // initial gas measurement for fee calculation
        uint256 startGas = gasleft();

        // decode the arguments from the instruction
        SweepERC20 memory arguments = abi.decode(instruction.arguments, (SweepERC20));

        // if first execution, validate the input
        if (executionState.executionCount == 0) {
            /// @dev we allow endBalance == threshold particularly to support the use-case of sweeping the account's entire balance
            if (
                arguments.token == address(0) || arguments.target == address(0)
                    || arguments.endBalance > arguments.threshold
            ) {
                revert InvalidArguments();
            }
        }

        // get the account's token balance
        uint256 balance = IERC20(arguments.token).balanceOf(address(this));

        // if the balance is under the threshold or equal to the endBalance, revert.
        // the endBalance check is to prevent the instruction from executing
        // when threshold == endBalance == balance because in this case we would have sweepAmount == 0
        // slither-disable-next-line incorrect-equality
        if (balance < arguments.threshold || balance == arguments.endBalance) {
            revert BalanceUnderThreshold();
        }

        // calculate the amount to sweep
        uint256 sweepAmount = balance - arguments.endBalance;

        // transfer the sweepAmount to the target address
        IERC20(arguments.token).safeTransfer(arguments.target, sweepAmount);

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this action has no auto-deactivation cases
        return false;
    }
}
