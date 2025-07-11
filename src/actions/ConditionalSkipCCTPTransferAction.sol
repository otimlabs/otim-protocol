// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICCTPRelayer} from "@skip-go-evm-contracts/CCTPRelayer/src/interfaces/ICCTPRelayer.sol";
import {ITokenController} from "./external/ITokenController.sol";
import {ISkipGoFeeOracle} from "./oracles/interfaces/ISkipGoFeeOracle.sol";

import {InstructionLib} from "../libraries/Instruction.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {
    IConditionalSkipCCTPTransferAction,
    INSTRUCTION_TYPEHASH,
    ARGUMENTS_TYPEHASH
} from "./interfaces/IConditionalSkipCCTPTransferAction.sol";

import {InvalidArguments, BalanceUnderThreshold, InsufficientBalanceForSkipGoFee} from "./errors/Errors.sol";

/// @title ConditionalSkipCCTPTransferAction
/// @author Otim Labs, Inc.
/// @notice
contract ConditionalSkipCCTPTransferAction is IAction, IConditionalSkipCCTPTransferAction, OtimFee {
    using InstructionLib for InstructionLib.Instruction;

    IERC20 public immutable usdc;
    ICCTPRelayer public immutable cctpRelayer;
    ITokenController public immutable tokenMinter;
    ISkipGoFeeOracle public immutable skipGoFeeOracle;

    constructor(
        address usdcAddress_,
        address cctpRelayerAddress_,
        address tokenMinterAddress_,
        address skipGoFeeOracleAddress_,
        address feeTokenRegistryAddress,
        address treasuryAddress,
        uint256 gasConstant_
    ) OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_) {
        usdc = IERC20(usdcAddress_);
        cctpRelayer = ICCTPRelayer(cctpRelayerAddress_);
        tokenMinter = ITokenController(tokenMinterAddress_);
        skipGoFeeOracle = ISkipGoFeeOracle(skipGoFeeOracleAddress_);
    }

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (ConditionalSkipCCTPTransfer))));
    }

    /// @inheritdoc IConditionalSkipCCTPTransferAction
    function hash(ConditionalSkipCCTPTransfer memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.destinationDomain,
                arguments.destinationMintRecipient,
                arguments.threshold,
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
        ConditionalSkipCCTPTransfer memory arguments = abi.decode(instruction.arguments, (ConditionalSkipCCTPTransfer));

        // if first execution, validate the input
        if (executionState.executionCount == 0) {
            // validate the arguments
            if (arguments.destinationMintRecipient == bytes32(0)) {
                revert InvalidArguments();
            }
        }

        // get the USDC token balance of this deposit account
        uint256 balance = usdc.balanceOf(address(this));

        // if the balance is less than or equal to the threshold, revert
        if (balance <= arguments.threshold) {
            revert BalanceUnderThreshold();
        }

        // get the Skip Go fee for bridging to the destination chain
        uint256 feeAmount = skipGoFeeOracle.getFee(arguments.destinationDomain);

        // the deposit account must have enough balance to cover the Skip Go fee
        if (balance <= feeAmount) {
            revert InsufficientBalanceForSkipGoFee();
        }

        // get the CCTP max burn amount per message for USDC
        uint256 maxBurnPerMessage = tokenMinter.burnLimitsPerMessage(address(usdc));

        // calculate the transfer amount taking into account the fee and the max burn per message
        uint256 transferAmount = balance - feeAmount > maxBurnPerMessage ? maxBurnPerMessage : balance - feeAmount;

        // approve the transfer amount plus the fee to the CCTP relayer contract
        // slither-disable-next-line unused-return
        usdc.approve(address(cctpRelayer), transferAmount + feeAmount);

        // request the CCTP transfer
        cctpRelayer.requestCCTPTransfer(
            transferAmount, arguments.destinationDomain, arguments.destinationMintRecipient, address(usdc), feeAmount
        );

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        return false;
    }
}
