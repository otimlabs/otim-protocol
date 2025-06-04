// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";

import {ITreasury} from "./interfaces/ITreasury.sol";

/// @title Treasury
/// @author Otim Labs, Inc.
/// @notice contract to collect user execution fees
contract Treasury is ITreasury, Ownable {
    using SafeERC20 for IERC20;

    constructor(address owner) Ownable(owner) {}

    /// @inheritdoc ITreasury
    function deposit() external payable {}

    /// @inheritdoc ITreasury
    function withdraw(address target, uint256 value) external onlyOwner {
        // check the target is not the zero address
        if (target == address(0)) {
            revert InvalidTarget();
        }

        // check the contract has enough balance to withdraw
        if (address(this).balance < value) {
            revert InsufficientBalance();
        }

        // withdraw the funds
        (bool success, bytes memory result) = target.call{value: value}("");

        // check if the withdrawal was successful
        if (!success) {
            revert WithdrawalFailed(result);
        }
    }

    /// @inheritdoc ITreasury
    function withdrawERC20(address token, address target, uint256 value) external onlyOwner {
        // check the target is not the zero address
        if (target == address(0)) {
            revert InvalidTarget();
        }

        // check the contract has enough balance to withdraw
        if (IERC20(token).balanceOf(address(this)) < value) {
            revert InsufficientBalance();
        }

        // withdraw the ERC20 tokens to the target
        IERC20(token).safeTransfer(target, value);
    }
}
