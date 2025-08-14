// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ITokenMessenger} from "./external/ITokenMessenger.sol";
import {ITokenController} from "./external/ITokenController.sol";

import {InstructionLib} from "../libraries/Instruction.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {ISweepCCTPAction, INSTRUCTION_TYPEHASH, ARGUMENTS_TYPEHASH} from "./interfaces/ISweepCCTPAction.sol";

import {InvalidArguments, BalanceUnderThreshold, CCTPTokenNotSupported} from "./errors/Errors.sol";

/// @title SweepCCTPAction
/// @author Otim Labs, Inc.
/// @notice an Action that sweeps ERC20 tokens from the user's account to a target on a different chain via CCTP when the balance is greater than or equal to a threshold
contract SweepCCTPAction is IAction, ISweepCCTPAction, OtimFee {
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
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (SweepCCTP))));
    }

    /// @inheritdoc ISweepCCTPAction
    function hash(SweepCCTP memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.token,
                arguments.destinationDomain,
                arguments.destinationMintRecipient,
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
    ) external override returns (bool) {
        // initial gas measurement for fee calculation
        uint256 startGas = gasleft();

        // decode the arguments from the instruction
        SweepCCTP memory arguments = abi.decode(instruction.arguments, (SweepCCTP));

        // if first execution, validate the arguments
        if (executionState.executionCount == 0) {
            if (
                arguments.token == address(0) || arguments.destinationMintRecipient == bytes32(0)
                    || arguments.endBalance > arguments.threshold
            ) {
                revert InvalidArguments();
            }
        }

        // get the user's token balance
        uint256 balance = IERC20(arguments.token).balanceOf(address(this));

        // if the balance is under the threshold or equal to the endBalance, revert.
        // the endBalance check is to prevent the instruction from executing
        // when threshold == endBalance == balance because in this case we would have transferAmount == 0
        // slither-disable-next-line incorrect-equality
        if (balance < arguments.threshold || balance == arguments.endBalance) {
            revert BalanceUnderThreshold();
        }

        // get the CCTP burnLimitPerMessage for the token
        uint256 burnLimitPerMessage = tokenMinter.burnLimitsPerMessage(arguments.token);

        // if the burnLimitPerMessage is zero, the token is not supported
        if (burnLimitPerMessage == 0) {
            revert CCTPTokenNotSupported();
        }

        // calculate the transferAmount
        uint256 transferAmount = balance - arguments.endBalance;

        // if the transferAmount is over the burnLimitPerMessage, emit an event and just transfer the burnLimitPerMessage
        if (transferAmount > burnLimitPerMessage) {
            transferAmount = burnLimitPerMessage;

            emit CCTPBurnLimitReached(arguments.token, burnLimitPerMessage);
        }

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
