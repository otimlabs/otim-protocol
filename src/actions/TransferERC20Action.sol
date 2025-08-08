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
    function hash(TransferERC20 memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.token,
                arguments.target,
                arguments.value,
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
        TransferERC20 memory arguments = abi.decode(instruction.arguments, (TransferERC20));

        // if first execution, validate the input
        if (executionState.executionCount == 0) {
            // validate the arguments
            if (arguments.token == address(0) || arguments.target == address(0) || arguments.value == 0) {
                revert InvalidArguments();
            }

            checkStart(arguments.schedule);
        } else {
            checkInterval(arguments.schedule, executionState.lastExecuted);
        }

        IERC20 transferToken = IERC20(arguments.token);

        // check if the account has enough balance to transfer
        if (transferToken.balanceOf(address(this)) < arguments.value) {
            revert InsufficientBalance();
        }

        // transfer the value to the target address
        transferToken.safeTransfer(arguments.target, arguments.value);

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this action has no auto-deactivation cases
        return false;
    }
}
