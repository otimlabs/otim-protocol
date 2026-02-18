// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC4626} from "@openzeppelin-contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

import {InstructionLib} from "../libraries/Instruction.sol";

import {Interval} from "./schedules/Interval.sol";
import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {
    IRequestDepositERC7540Action,
    INSTRUCTION_TYPEHASH,
    ARGUMENTS_TYPEHASH
} from "./interfaces/IRequestDepositERC7540Action.sol";
import {IERC7540Deposit} from "./external/IERC7540.sol";

import {InvalidArguments, InsufficientBalance, TotalSharesTooLow, MaxDepositTooLow} from "./errors/Errors.sol";

/// @title RequestDepositERC7540Action
/// @author Otim Labs, Inc.
/// @notice an Action that submits an asynchronous deposit request to an ERC7540 vault
contract RequestDepositERC7540Action is IAction, IRequestDepositERC7540Action, Interval, OtimFee {
    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (RequestDepositERC7540))));
    }

    /// @inheritdoc IRequestDepositERC7540Action
    function hash(RequestDepositERC7540 memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.vault,
                arguments.assets,
                arguments.recipient,
                arguments.controller,
                arguments.minDeposit,
                arguments.minTotalShares,
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
        RequestDepositERC7540 memory arguments = abi.decode(instruction.arguments, (RequestDepositERC7540));

        // if first execution, validate the input
        if (executionState.executionCount == 0) {
            if (
                arguments.vault == address(0) || arguments.assets == 0 || arguments.recipient == address(0)
                    || arguments.controller == address(0) || arguments.minTotalShares == 0
            ) {
                revert InvalidArguments();
            }

            checkStart(arguments.schedule);
        } else {
            checkInterval(arguments.schedule, executionState.lastExecuted);
        }

        // get the underlying token (ERC7540 vaults are ERC4626-compatible for asset())
        address underlyingToken = IERC4626(arguments.vault).asset();

        // check if the account has enough balance to request
        if (IERC20(underlyingToken).balanceOf(address(this)) < arguments.assets) {
            revert InsufficientBalance();
        }

        // check if vault total shares is too low
        if (IERC4626(arguments.vault).totalSupply() < arguments.minTotalShares) {
            revert TotalSharesTooLow();
        }

        // approve the vault to pull assets from the executing account (owner)
        // slither-disable-next-line unused-return
        IERC20(underlyingToken).approve(arguments.vault, arguments.assets);

        // submit async deposit request: owner = address(this), controller from arguments
        uint256 requestId =
            IERC7540Deposit(arguments.vault).requestDeposit(arguments.assets, arguments.controller, address(this));

        // if the request amount is less than the minimum deposit amount, revert
        if (
            IERC7540Deposit(arguments.vault).pendingDepositRequest(requestId, arguments.controller)
                < arguments.minDeposit
        ) {
            revert MaxDepositTooLow();
        }

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this action has no auto-deactivation cases
        return false;
    }
}
