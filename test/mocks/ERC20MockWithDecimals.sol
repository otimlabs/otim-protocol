// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {ERC20DecimalsMock} from "@openzeppelin-contracts/mocks/token/ERC20DecimalsMock.sol";
import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract ERC20MockWithDecimals is IERC20Metadata, ERC20DecimalsMock {
    constructor(uint8 decimals_) ERC20DecimalsMock(decimals_) ERC20("", "") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
