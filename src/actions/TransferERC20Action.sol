// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {InstructionLib} from "../libraries/Instruction.sol";

import {Interval} from "./schedules/Interval.sol";
import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {ITransferERC20Action, INSTRUCTION_TYPEHASH, ARGUMENTS_TYPEHASH} from "./interfaces/ITransferERC20Action.sol";

import {InvalidArguments, InsufficientBalance} from "./errors/Errors.sol";

/// @title TransferERC20Action
/// @author Otim Labs, Inc.
/// @notice an Action that transfers an ERC20 token to a target address
contract TransferERC20Action is IAction, ITransferERC20Action, Interval, OtimFee {
    using SafeERC20 for IERC20;

    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (TransferERC20))));
    }

    /// @inheritdoc ITransferERC20Action
    function hash(TransferERC20 memory transferERC20) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                transferERC20.token,
                transferERC20.target,
                transferERC20.value,
                hash(transferERC20.schedule),
                hash(transferERC20.fee)
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
        TransferERC20 memory transferERC20 = abi.decode(instruction.arguments, (TransferERC20));

        // if first execution, validate the input
        if (executionState.executionCount == 0) {
            // validate the arguments
            if (transferERC20.token == address(0) || transferERC20.target == address(0) || transferERC20.value == 0) {
                revert InvalidArguments();
            }

            checkStart(transferERC20.schedule);
        } else {
            checkInterval(transferERC20.schedule, executionState.lastExecuted);
        }

        IERC20 transferToken = IERC20(transferERC20.token);

        // check if the account has enough balance to transfer
        if (transferToken.balanceOf(address(this)) < transferERC20.value) {
            revert InsufficientBalance();
        }

        // transfer the value to the target address
        transferToken.safeTransfer(transferERC20.target, transferERC20.value);

        // charge the fee
        chargeFee(startGas - gasleft(), transferERC20.fee);

        // this action has no auto-deactivation cases
        return false;
    }
}
