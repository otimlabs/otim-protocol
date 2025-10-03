// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {ERC4626} from "@openzeppelin-contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";

contract ERC4626Mock is ERC4626 {
    constructor(IERC20 _asset) ERC4626(_asset) ERC20("Mock Vault", "vMOCK") {
        _maxDeposit = type(uint256).max;
        _maxWithdraw = type(uint256).max;
    }

    uint256 private _totalAssets;
    uint256 private _maxDeposit;
    uint256 private _maxWithdraw;

    function totalAssets() public view override returns (uint256) {
        return _totalAssets;
    }

    function maxDeposit(address) public view override returns (uint256) {
        return _maxDeposit;
    }

    function maxWithdraw(address) public view override returns (uint256) {
        return _maxWithdraw;
    }

    function setTotalAssets(uint256 totalAssets_) public {
        _totalAssets = totalAssets_;
    }

    function setMaxDeposit(uint256 maxDeposit_) public {
        _maxDeposit = maxDeposit_;
    }

    function setMaxWithdraw(uint256 maxWithdraw_) public {
        _maxWithdraw = maxWithdraw_;
    }
}
