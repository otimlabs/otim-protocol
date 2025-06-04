// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

/// @title DepositAccount
/// @author Otim Labs, Inc.
/// @notice a transient contract that is deployed to sweep funds from a predetermined address
contract DepositAccount {
    using SafeERC20 for IERC20;

    /// @notice owner of the DepositAccount
    address payable internal immutable owner;

    error Unauthorized();

    constructor() {
        owner = payable(msg.sender);
    }

    /// @notice ensures only the owner can call the function
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    /// @notice allows contract to receive ether
    receive() external payable {}

    /// @notice sweep ether from the deposit account to the recipient
    /// @param recipient - the address to send the ether to
    function sweep(address payable recipient) external onlyOwner {
        // all ether at this address is credited to the recipient
        selfdestruct(recipient);
    }

    /// @notice sweep ERC20 tokens from the deposit account to the recipient
    /// @param token - the address of the ERC20 token to sweep
    /// @param recipient - the address to send the tokens to
    function sweep(address token, address recipient) external onlyOwner {
        // send all tokens at this address to the recipient
        IERC20(token).safeTransfer(recipient, IERC20(token).balanceOf(address(this)));

        // all ether at this address is credited to the owner (and will be sent back)
        selfdestruct(owner);
    }
}
