// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC4626} from "@openzeppelin-contracts/interfaces/IERC4626.sol";

import {InstructionLib} from "../libraries/Instruction.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {
    ISweepWithdrawERC4626Action,
    INSTRUCTION_TYPEHASH,
    ARGUMENTS_TYPEHASH
} from "./interfaces/ISweepWithdrawERC4626Action.sol";

import {InvalidArguments, TotalSharesTooLow, BalanceUnderThreshold} from "./errors/Errors.sol";

/// @title SweepWithdrawERC4626Action
/// @author Otim Labs, Inc.
/// @notice an Action that withdraws ERC20 tokens from an ERC4626 vault to a recipient when the maxWithdraw balance is greater than or equal to a threshold
contract SweepWithdrawERC4626Action is IAction, ISweepWithdrawERC4626Action, OtimFee {
    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (SweepWithdrawERC4626))));
    }

    /// @inheritdoc ISweepWithdrawERC4626Action
    function hash(SweepWithdrawERC4626 memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.vault,
                arguments.recipient,
                arguments.threshold,
                arguments.endBalance,
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
        SweepWithdrawERC4626 memory arguments = abi.decode(instruction.arguments, (SweepWithdrawERC4626));

        // if first execution, validate the input
        if (executionState.executionCount == 0) {
            if (
                arguments.vault == address(0) || arguments.recipient == address(0)
                    || arguments.endBalance > arguments.threshold || arguments.minTotalShares == 0
            ) {
                revert InvalidArguments();
            }
        }

        // get the max withdraw amount
        uint256 maxWithdraw = IERC4626(arguments.vault).maxWithdraw(address(this));

        // if the max withdraw amount is under the threshold or equal to the endBalance, revert
        // slither-disable-next-line incorrect-equality
        if (maxWithdraw < arguments.threshold || maxWithdraw == arguments.endBalance) {
            revert BalanceUnderThreshold();
        }

        // check if vault total shares is too low
        if (IERC4626(arguments.vault).totalSupply() < arguments.minTotalShares) {
            revert TotalSharesTooLow();
        }

        // withdraw from the vault
        // slither-disable-next-line unused-return
        IERC4626(arguments.vault).withdraw(maxWithdraw - arguments.endBalance, arguments.recipient, address(this));

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this action has no auto-deactivation cases
        return false;
    }
}
