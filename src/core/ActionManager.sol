// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IActionManager} from "./interfaces/IActionManager.sol";
import {AccessControl} from "@openzeppelin-contracts/access/AccessControl.sol";

/// @title ActionManager
/// @author Otim Labs, Inc.
/// @notice an Otim-owned contract for managing Otim Actions
contract ActionManager is IActionManager, AccessControl {
    /// @notice global lock status
    bool private _globalLock;
    /// @notice mapping of available Actions
    mapping(address => bool) private _available;

    /// @notice AccessControl role for globally locking Actions
    bytes32 public constant KILL_SWITCH_ROLE = keccak256("KILL_SWITCH_ROLE");

    /// @dev `owner` is passed-in in the constructor so we don't need to use our deployer key for admin tasks
    /// @dev the KILL_SWITCH_ROLE is reserved for globally locking ActionManager in the event of an emergency.
    ///      `owner` is intended to be a multi-sig, while a `killSwitchOwner` (role granted after deployment) will be a less secure,
    ///      single-key wallet to allow Otim to take swift action in the event of an emergency. `owner` is also granted the
    ///      KILL_SWITCH_ROLE so that it can also globally lock ActionManager if necessary.
    constructor(address owner) {
        // add `owner` to the DEFAULT_ADMIN_ROLE
        _grantRole(DEFAULT_ADMIN_ROLE, owner);

        /// @dev allows accounts with DEFAULT_ADMIN_ROLE to call `grantRole` and `revokeRole` for KILL_SWITCH_ROLE, see AccessControl.sol
        ///      after deployment, `owner` will be able to grant the KILL_SWITCH_ROLE to a `killSwitchOwner` account
        _setRoleAdmin(KILL_SWITCH_ROLE, DEFAULT_ADMIN_ROLE);

        // grant `owner` the KILL_SWITCH_ROLE (so `owner` can also globally lock Actions)
        _grantRole(KILL_SWITCH_ROLE, owner);
    }

    /// @notice makes an Action available for use in Instructions
    /// @param action - the address of the Action
    function addAction(address action) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_available[action]) revert AlreadyAdded();

        _available[action] = true;
        emit ActionAdded(action);
    }

    /// @notice removes an Action, making it unavailable for use in Instructions
    /// @param action - the address of the Action
    function removeAction(address action) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!_available[action]) revert AlreadyRemoved();

        delete _available[action];
        emit ActionRemoved(action);
    }

    /// @notice locks all Actions
    function lockAllActions() external onlyRole(KILL_SWITCH_ROLE) {
        if (_globalLock) revert AlreadyLocked();

        _globalLock = true;
        emit ActionsGloballyLocked();
    }

    /// @notice unlocks all Actions
    /// @dev does NOT unlock Actions that have been individually locked
    function unlockAllActions() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!_globalLock) revert AlreadyUnlocked();

        _globalLock = false;
        emit ActionsGloballyUnlocked();
    }

    /// @inheritdoc IActionManager
    function isExecutable(address action) external view returns (bool) {
        return _available[action] && !_globalLock;
    }

    /// @notice returns true if global lock is engaged
    function isGloballyLocked() public view returns (bool) {
        return _globalLock;
    }
}
