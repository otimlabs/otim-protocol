// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ITokenMessenger} from "../../actions/external/ITokenMessenger.sol";

/// @title CCTPDepositAccount
/// @author Otim Labs, Inc.
/// @notice a transient contract that is deployed to sweep funds from a predetermined address and bridge via CCTP
contract CCTPDepositAccount {
    using SafeERC20 for IERC20;

    /// @notice owner of the DepositAccount
    address payable internal immutable owner;
    /// @notice the CCTP token messenger contract
    ITokenMessenger internal immutable tokenMessenger;

    error Unauthorized();

    constructor(address tokenMessengerAddress) {
        owner = payable(msg.sender);
        tokenMessenger = ITokenMessenger(tokenMessengerAddress);
    }

    /// @notice ensures only the owner can call the function
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    /// @notice allows contract to receive ether
    receive() external payable {}

    /// @notice sweep ether from the deposit account to the recipient
    /// @dev this is back-up in the event that a user transfers ETH to this deposit account
    /// @param recipient - the address to send the ether to
    function sweep(address payable recipient) external onlyOwner {
        // all ether at this address is credited to the recipient
        selfdestruct(recipient);
    }

    /// @notice sweep ERC20 tokens from the deposit account to the recipient
    /// @dev this is back-up in the event that a user transfers a token not supported by CCTP to this deposit account
    /// @param token - the address of the ERC20 token to sweep
    /// @param recipient - the address to send the tokens to
    function sweep(address token, address recipient) external onlyOwner {
        // send all tokens at this address to the recipient
        IERC20(token).safeTransfer(recipient, IERC20(token).balanceOf(address(this)));

        // all ether at this address is credited to the owner (and will be sent back)
        selfdestruct(owner);
    }

    /// @notice sweep ERC20 tokens from this deposit account to the CCTP token messenger contract
    /// @param token - the address of the ERC20 token to sweep
    /// @param destinationDomain - the domain ID of the destination chain
    /// @param destinationMintRecipient - the address of the recipient on the destination chain (in bytes32 format)
    function sweepToCCTP(
        address token,
        uint32 destinationDomain,
        bytes32 destinationMintRecipient,
        uint256 maxBurnPerMessage
    ) external onlyOwner {
        uint256 burnAmount = IERC20(token).balanceOf(address(this));

        if (burnAmount > maxBurnPerMessage) {
            burnAmount = maxBurnPerMessage;
        }

        // approve all tokens in this deposit account to the CCTP TokenMessenger contract
        IERC20(token).safeIncreaseAllowance(address(tokenMessenger), burnAmount);

        // initiate the CCTP transfer
        // slither-disable-next-line unused-return
        tokenMessenger.depositForBurn(burnAmount, destinationDomain, destinationMintRecipient, token);

        // all ether at this address is credited to the owner (and will be sent back)
        selfdestruct(owner);
    }
}
