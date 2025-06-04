// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {IFeeTokenRegistry} from "../../infrastructure/interfaces/IFeeTokenRegistry.sol";
import {ITreasury} from "../../infrastructure/interfaces/ITreasury.sol";

import {IOtimFee, FEE_TYPEHASH} from "./interfaces/IOtimFee.sol";

/// @title OtimFee
/// @author Otim Labs, Inc.
/// @notice abstract contract for the Otim centralized fee model
abstract contract OtimFee is IOtimFee {
    using SafeERC20 for IERC20;

    /// @notice the Otim fee token registry contract for converting wei to ERC20 tokens
    IFeeTokenRegistry public immutable feeTokenRegistry;
    /// @notice the Otim treasury contract that receives fees
    ITreasury public immutable treasury;
    /// @notice the gas constant used to calculate the fee
    uint256 public immutable gasConstant;

    constructor(address feeTokenRegistryAddress, address treasuryAddress, uint256 gasConstant_) {
        feeTokenRegistry = IFeeTokenRegistry(feeTokenRegistryAddress);
        treasury = ITreasury(treasuryAddress);
        gasConstant = gasConstant_;
    }

    /// @inheritdoc IOtimFee
    function hash(Fee memory fee) public pure returns (bytes32) {
        return keccak256(
            abi.encode(FEE_TYPEHASH, fee.token, fee.maxBaseFeePerGas, fee.maxPriorityFeePerGas, fee.executionFee)
        );
    }

    /// @inheritdoc IOtimFee
    function chargeFee(uint256 gasUsed, Fee memory fee) public override {
        // fee.executionFee == 0 is a magic value signifying a sponsored Instruction
        if (fee.executionFee == 0) return;

        // check if the base fee is too high
        if (block.basefee > fee.maxBaseFeePerGas && fee.maxBaseFeePerGas != 0) {
            revert BaseFeePerGasTooHigh();
        }

        // check if the priority fee is too high
        if (tx.gasprice - block.basefee > fee.maxPriorityFeePerGas) {
            revert PriorityFeePerGasTooHigh();
        }

        // calculate the total cost of the gas used in the transaction
        uint256 weiGasCost = (gasUsed + gasConstant) * tx.gasprice;

        // if fee.token is address(0), the fee is paid in native currency
        if (fee.token == address(0)) {
            // calculate the fee cost based on the gas used and the additional fee
            uint256 weiTotalCost = weiGasCost + fee.executionFee;

            // check if the user has enough balance to pay the fee
            if (address(this).balance < weiTotalCost) {
                revert InsufficientFeeBalance();
            }

            // transfer to the treasury contract
            // slither-disable-next-line arbitrary-send-eth
            treasury.deposit{value: weiTotalCost}();
        } else {
            // calculate the fee cost based on the cost of the gas used (denominated in the fee token) and the execution fee
            uint256 tokenTotalCost = feeTokenRegistry.weiToToken(fee.token, weiGasCost) + fee.executionFee;

            // check if the user has enough balance to pay the fee
            if (IERC20(fee.token).balanceOf(address(this)) < tokenTotalCost) {
                revert InsufficientFeeBalance();
            }

            // transfer to the treasury contract
            IERC20(fee.token).safeTransfer(address(treasury), tokenTotalCost);
        }
    }
}
