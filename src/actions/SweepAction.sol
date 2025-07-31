// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {InstructionLib} from "../libraries/Instruction.sol";
import {AssemblyUtils} from "./libraries/AssemblyUtils.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {ISweepAction, INSTRUCTION_TYPEHASH, ARGUMENTS_TYPEHASH} from "./interfaces/ISweepAction.sol";

import {InvalidArguments, BalanceUnderThreshold} from "./errors/Errors.sol";

/// @title SweepAction
/// @author Otim Labs, Inc.
/// @notice an Action that sweeps native currency from the user's account to a target when the balance is greater than or equal to a threshold
contract SweepAction is IAction, ISweepAction, OtimFee {
    using InstructionLib for InstructionLib.Instruction;

    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_)
        OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_)
    {}

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (Sweep))));
    }

    /// @inheritdoc ISweepAction
    function hash(Sweep memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.target,
                arguments.threshold,
                arguments.endBalance,
                arguments.gasLimit,
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
        Sweep memory arguments = abi.decode(instruction.arguments, (Sweep));

        // if first execution, validate the input
        if (executionState.executionCount == 0) {
            /// @dev we allow endBalance == threshold particularly to support the use-case of sweeping the account's entire balance
            if (arguments.target == address(0) || arguments.endBalance > arguments.threshold) {
                revert InvalidArguments();
            }
        }

        // get the account's balance
        uint256 balance = address(this).balance;

        // if the balance is under the threshold or equal to the endBalance, revert.
        // the endBalance check is to prevent the instruction from executing
        // when threshold == endBalance == balance because in this case we would have sweepAmount == 0
        // slither-disable-next-line incorrect-equality
        if (balance < arguments.threshold || balance == arguments.endBalance) {
            revert BalanceUnderThreshold();
        }

        // calculate the amount to sweep
        uint256 sweepAmount = balance - arguments.endBalance;

        // transfer the sweepAmount to the target address, with a gas limit, and without returning any data
        bool success = AssemblyUtils.safeTransferNoReturn(arguments.target, sweepAmount, arguments.gasLimit);

        // if the sweep fails, charge the user for the gas used, emit an event, and automatically deactivate the instruction
        // we do this instead of reverting to protect the Executor from gas griefing attacks
        if (!success) {
            // if the fee is not sponsored, set the execution fee to 1 to only charge the user for gas used
            if (arguments.fee.executionFee > 0) {
                arguments.fee.executionFee = 1;
            }

            // emit that the sweep failed
            emit SweepActionFailed(arguments.target);

            // deactivate the instruction
            deactivate = true;
        }

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);
    }
}
