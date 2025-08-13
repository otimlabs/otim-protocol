// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ITokenMessenger} from "./external/ITokenMessenger.sol";
import {ITokenController} from "./external/ITokenController.sol";

import {InstructionLib} from "../libraries/Instruction.sol";

import {Interval} from "./schedules/Interval.sol";
import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {ITransferCCTPAction, INSTRUCTION_TYPEHASH, ARGUMENTS_TYPEHASH} from "./interfaces/ITransferCCTPAction.sol";

import {InvalidArguments, InsufficientBalance, CCTPTokenNotSupported} from "./errors/Errors.sol";

/// @title TransferCCTPAction
/// @author Otim Labs, Inc.
/// @notice an Action that transfers ERC20 tokens from the user's account to a target on a different chain via CCTP
contract TransferCCTPAction is IAction, ITransferCCTPAction, Interval, OtimFee {
    using InstructionLib for InstructionLib.Instruction;

    /// @notice the CCTP TokenMessenger contract
    ITokenMessenger public immutable tokenMessenger;
    /// @notice the CCTP TokenMinter contract
    /// @dev the TokenMinter contract implements the ITokenController interface
    ITokenController public immutable tokenMinter;

    constructor(
        address tokenMessengerAddress,
        address tokenMinterAddress,
        address feeTokenRegistryAddress,
        address treasuryAddress,
        uint256 gasConstant_
    ) OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_) {
        tokenMessenger = ITokenMessenger(tokenMessengerAddress);
        tokenMinter = ITokenController(tokenMinterAddress);
    }

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (TransferCCTP))));
    }

    /// @inheritdoc ITransferCCTPAction
    function hash(TransferCCTP memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.token,
                arguments.amount,
                arguments.destinationDomain,
                arguments.destinationMintRecipient,
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
        TransferCCTP memory arguments = abi.decode(instruction.arguments, (TransferCCTP));

        // if first execution, validate the arguments
        if (executionState.executionCount == 0) {
            if (
                arguments.token == address(0) || arguments.amount == 0
                    || arguments.destinationMintRecipient == bytes32(0)
            ) {
                revert InvalidArguments();
            }

            checkStart(arguments.schedule);
        } else {
            checkInterval(arguments.schedule, executionState.lastExecuted);
        }

        // get the user's token balance
        uint256 balance = IERC20(arguments.token).balanceOf(address(this));

        // if the balance is less than the amount, revert
        if (balance < arguments.amount) {
            revert InsufficientBalance();
        }

        // get the CCTP burnLimitPerMessage for the token
        uint256 burnLimitPerMessage = tokenMinter.burnLimitsPerMessage(arguments.token);

        // if the burnLimitPerMessage is zero, the token is not supported
        if (burnLimitPerMessage == 0) {
            revert CCTPTokenNotSupported();
        }

        // if the transferAmount is over the burnLimitPerMessage, just transfer the burnLimitPerMessage
        uint256 transferAmount = arguments.amount > burnLimitPerMessage ? burnLimitPerMessage : arguments.amount;

        // approve the transferAmount to the CCTP TokenMessenger contract
        // slither-disable-next-line unused-return
        IERC20(arguments.token).approve(address(tokenMessenger), transferAmount);

        // initiate CCTP transfer
        // slither-disable-next-line unused-return
        tokenMessenger.depositForBurn(
            transferAmount, arguments.destinationDomain, arguments.destinationMintRecipient, arguments.token
        );

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this action has no auto-deactivation cases
        return false;
    }
}
