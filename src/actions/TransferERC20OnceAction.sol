// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {InstructionLib} from "../libraries/Instruction.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {
    ITransferERC20OnceAction,
    INSTRUCTION_TYPEHASH,
    ARGUMENTS_TYPEHASH
} from "./interfaces/ITransferERC20OnceAction.sol";

import {InvalidArguments, InsufficientBalance} from "./errors/Errors.sol";

/// @title TransferERC20OnceAction
/// @author Otim Labs, Inc.
/// @notice an Action that makes a one-time transfer of an ERC20 token to a target address
contract TransferERC20OnceAction is IAction, ITransferERC20OnceAction, OtimFee {
    using SafeERC20 for IERC20;

    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (TransferERC20Once))));
    }

    /// @inheritdoc ITransferERC20OnceAction
    function hash(TransferERC20Once memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(ARGUMENTS_TYPEHASH, arguments.token, arguments.target, arguments.value, hash(arguments.fee))
        );
    }

    /// @inheritdoc IAction
    function execute(
        InstructionLib.Instruction calldata instruction,
        InstructionLib.Signature calldata,
        InstructionLib.ExecutionState calldata
    ) external override returns (bool) {
        // initial gas measurement for fee calculation
        uint256 startGas = gasleft();

        // decode the arguments from the instruction
        TransferERC20Once memory arguments = abi.decode(instruction.arguments, (TransferERC20Once));

        // validate the arguments
        if (
            instruction.maxExecutions != 1 || arguments.token == address(0) || arguments.target == address(0)
                || arguments.value == 0
        ) {
            revert InvalidArguments();
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
