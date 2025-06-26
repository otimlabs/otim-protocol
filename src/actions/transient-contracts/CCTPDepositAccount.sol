// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICCTPRelayer} from "@skip-go-evm-contracts/CCTPRelayer/src/interfaces/ICCTPRelayer.sol";
import {ITokenController} from "../external/ITokenController.sol";
import {ISkipGoFeeOracle} from "../../actions/oracles/interfaces/ISkipGoFeeOracle.sol";

/// @title CCTPDepositAccount
/// @author Otim Labs, Inc.
/// @notice a transient contract that is deployed to sweep funds from a predetermined address to the SkipGo CCTP relayer contract
contract CCTPDepositAccount {
    using SafeERC20 for IERC20;

    /// @notice the USDC token contract
    IERC20 internal immutable usdc;
    /// @notice the SkipGo CCTP relayer contract
    ICCTPRelayer internal immutable cctpRelayer;
    /// @notice the CCTP TokenMinter contract
    ITokenController internal immutable tokenMinter;
    /// @notice the SkipGoFeeOracle contract
    ISkipGoFeeOracle internal immutable skipGoFeeOracle;

    /// @notice the owner of the CCTPDepositAccount
    address payable internal immutable owner;
    /// @notice the expected depositor for the CCTPDepositAccount
    address payable internal immutable depositor;
    /// @notice the CCTP domain ID for the destination chain
    uint32 internal immutable destinationDomain;
    /// @notice the CCTP mint recipient address in bytes32 format
    bytes32 internal immutable destinationMintRecipient;

    error BalanceUnderThreshold();
    error InsufficientBalanceForSkipGoFee();

    constructor(
        address usdcAddress,
        address cctpRelayerAddress,
        address tokenMinterAddress,
        address skipGoFeeOracleAddress,
        address depositor_,
        uint32 destinationDomain_,
        bytes32 destinationMintRecipient_
    ) {
        // slither-disable-start missing-zero-check
        usdc = IERC20(usdcAddress);
        cctpRelayer = ICCTPRelayer(cctpRelayerAddress);
        tokenMinter = ITokenController(tokenMinterAddress);
        skipGoFeeOracle = ISkipGoFeeOracle(skipGoFeeOracleAddress);

        owner = payable(msg.sender);
        depositor = payable(depositor_);
        destinationDomain = destinationDomain_;
        destinationMintRecipient = destinationMintRecipient_;
        // slither-disable-end missing-zero-check
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert();
        _;
    }

    /// @notice sweep ERC20 tokens and ether from the deposit account back to the depositor
    /// @dev this is back-up in the event that a user transfers a token not supported by CCTP to this deposit account
    /// @param token - the address of the ERC20 token to sweep
    function recover(address token) external onlyOwner {
        if (token != address(0)) {
            // send all tokens at this address to the recipient
            IERC20(token).safeTransfer(depositor, IERC20(token).balanceOf(address(this)));
        }

        // all ether at this address is credited to the owner (and will be sent back)
        selfdestruct(depositor);
    }

    /// @notice sweep USDC tokens from this deposit account to the SkipGo CCTP relayer contract
    /// @param threshold - the minimum balance required to perform the sweep
    function sweep(uint256 threshold) external onlyOwner {
        // get the USDC token balance of this deposit account
        uint256 balance = usdc.balanceOf(address(this));

        // if the balance is less than or equal to the threshold, revert
        if (balance <= threshold) {
            revert BalanceUnderThreshold();
        }

        // get the SkipGo fee for bridging to the destination chain
        uint256 feeAmount = skipGoFeeOracle.getFee(destinationDomain);

        // the deposit account must have enough balance to cover the SkipGo fee
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
            transferAmount, destinationDomain, destinationMintRecipient, address(usdc), feeAmount
        );

        // selfdestruct and credit any ether to the depositor
        selfdestruct(depositor);
    }
}
