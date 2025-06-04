// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

/// @title IActionManager
/// @author Otim Labs, Inc.
/// @notice interface for ActionManager contract
interface IActionManager {
    /// @notice emitted when an Action is added
    event ActionAdded(address indexed action);
    /// @notice emitted when an Action is removed
    event ActionRemoved(address indexed action);
    /// @notice emitted when all Actions are globally locked
    event ActionsGloballyLocked();
    /// @notice emitted when all Actions are globally unlocked
    event ActionsGloballyUnlocked();

    error AlreadyAdded();
    error AlreadyRemoved();
    error AlreadyLocked();
    error AlreadyUnlocked();

    /// @notice returns Action metadata
    /// @param action - the address of the Action
    /// @return executable - true if the Action exists and is not locked
    function isExecutable(address action) external view returns (bool);
}
