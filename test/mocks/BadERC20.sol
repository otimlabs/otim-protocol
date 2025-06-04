// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

/// @notice a dummy ERC20 token contract that fails all ERC20 functions
contract BadERC20Mock is IERC20 {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    function mint(address account, uint256 amount) external {
        _balances[account] += amount;
        _totalSupply += amount;
    }

    function burn(address account, uint256 amount) external {
        _balances[account] -= amount;
        _totalSupply -= amount;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address, uint256) external pure returns (bool) {
        return false;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return false;
    }
}
