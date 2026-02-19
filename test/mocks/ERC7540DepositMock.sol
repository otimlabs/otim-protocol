// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC7540Deposit} from "../../src/actions/external/IERC7540.sol";

/// @notice Minimal mock vault implementing ERC7540 deposit request flow for unit tests.
/// @dev Implements requestDeposit (pulls assets, records pending), pendingDepositRequest,
///      and ERC4626-compatible asset() and totalSupply() for action validation.
contract ERC7540DepositMock {
    using SafeERC20 for IERC20;

    IERC20 private _asset;
    uint256 private _totalSupply;

    mapping(address => uint256) private _pendingAssets;

    constructor(IERC20 asset_) {
        _asset = asset_;
        _totalSupply = 100e6; // default so minTotalShares checks pass
    }

    function asset() external view returns (address) {
        return address(_asset);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function setTotalSupply(uint256 totalSupply_) external {
        _totalSupply = totalSupply_;
    }

    /// @dev requestId is always 0 (single aggregated request per controller for tests).
    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256 requestId) {
        _asset.safeTransferFrom(owner, address(this), assets);
        _pendingAssets[controller] += assets;
        emit IERC7540Deposit.DepositRequest(controller, owner, 0, msg.sender, assets);
        return 0;
    }

    function pendingDepositRequest(uint256, address controller) external view returns (uint256 pendingAssets) {
        return _pendingAssets[controller];
    }
}
