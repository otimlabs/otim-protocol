// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC4626} from "@openzeppelin-contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

import {InstructionLib} from "../libraries/Instruction.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {
    ISweepRequestDepositERC7540Action,
    INSTRUCTION_TYPEHASH,
    ARGUMENTS_TYPEHASH
} from "./interfaces/ISweepRequestDepositERC7540Action.sol";
import {IERC7540Deposit} from "./external/IERC7540.sol";

import {InvalidArguments, BalanceUnderThreshold, TotalSharesTooLow, MaxDepositTooLow} from "./errors/Errors.sol";

/// @title SweepRequestDepositERC7540Action
/// @author Otim Labs, Inc.
/// @notice an Action that submits an async deposit request to an ERC7540 vault when the underlying balance is greater than or equal to a threshold
contract SweepRequestDepositERC7540Action is IAction, ISweepRequestDepositERC7540Action, OtimFee {
    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (SweepRequestDepositERC7540))));
    }

    /// @inheritdoc ISweepRequestDepositERC7540Action
    function hash(SweepRequestDepositERC7540 memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.vault,
                arguments.controller,
                arguments.threshold,
                arguments.endBalance,
                arguments.minDeposit,
                arguments.minTotalShares,
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
        SweepRequestDepositERC7540 memory arguments = abi.decode(instruction.arguments, (SweepRequestDepositERC7540));

        // if first execution, validate the input
        if (executionState.executionCount == 0) {
            if (
                arguments.vault == address(0) || arguments.controller == address(0)
                    || arguments.endBalance > arguments.threshold || arguments.minTotalShares == 0
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
        // when threshold == endBalance == balance because in this case we would have requestAmount == 0
        // slither-disable-next-line incorrect-equality
        if (balance < arguments.threshold || balance == arguments.endBalance) {
            revert BalanceUnderThreshold();
        }

        // check if vault total shares is too low
        if (IERC4626(arguments.vault).totalSupply() < arguments.minTotalShares) {
            revert TotalSharesTooLow();
        }

        // initialize request amount
        uint256 requestAmount = balance - arguments.endBalance;

        // slither-disable-start reentrancy-balance
        // False positive: detector links IERC20.balanceOf above to the check below, but that check uses
        // IERC7540.pendingDepositRequest (vault state), not token balance.
        // approve the vault to pull assets from the executing account (owner)
        // slither-disable-next-line unused-return
        IERC20(underlyingToken).approve(arguments.vault, requestAmount);

        // submit async deposit request: owner = address(this), controller from arguments
        uint256 requestId =
            IERC7540Deposit(arguments.vault).requestDeposit(requestAmount, arguments.controller, address(this));

        // if the request amount is less than the minimum deposit amount, revert
        if (
            IERC7540Deposit(arguments.vault).pendingDepositRequest(requestId, arguments.controller)
                < arguments.minDeposit
        ) {
            revert MaxDepositTooLow();
        }
        // slither-disable-end reentrancy-balance

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this action has no auto-deactivation cases
        return false;
    }
}
