// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {ERC4626} from "@openzeppelin-contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";

contract ERC4626Mock is ERC4626 {
    constructor(IERC20 _asset) ERC4626(_asset) ERC20("Mock Vault", "vMOCK") {}

    uint256 private _totalAssets;
    uint256 private _maxDeposit;

    function totalAssets() public view override returns (uint256) {
        return _totalAssets;
    }

    function maxDeposit(address) public view override returns (uint256) {
        return _maxDeposit;
    }

    function setTotalAssets(uint256 totalAssets_) public {
        _totalAssets = totalAssets_;
    }

    function setMaxDeposit(uint256 maxDeposit_) public {
        _maxDeposit = maxDeposit_;
    }
}
