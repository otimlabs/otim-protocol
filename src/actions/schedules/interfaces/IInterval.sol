// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

bytes32 constant SCHEDULE_TYPEHASH =
    keccak256("Schedule(uint256 startAt,uint256 startBy,uint256 interval,uint256 timeout)");

/// @title IInterval
/// @author Otim Labs, Inc.
/// @notice interface for the Interval schedule
interface IInterval {
    /// @notice interval schedule struct
    /// @param startAt - the timestamp the action can start at
    /// @param startBy - the timestamp the action must start by
    /// @param interval - the number of seconds between each execution
    /// @param timeout - the number of seconds after the interval the action can still be executed
    struct Schedule {
        uint256 startAt;
        uint256 startBy;
        uint256 interval;
        uint256 timeout;
    }

    /// @notice calculates the EIP-712 hash of the Schedule struct
    /// @param schedule - the schedule to hash
    /// @return hash - the EIP-712 hash of the Schedule
    function hash(Schedule memory schedule) external pure returns (bytes32);

    /// @notice checks the start time of the schedule
    /// @param schedule - the schedule to check
    function checkStart(Schedule memory schedule) external view;

    /// @notice checks the interval of the schedule
    /// @param schedule - the schedule to check
    /// @param lastExecuted - the last time the action was executed
    function checkInterval(Schedule memory schedule, uint256 lastExecuted) external view;

    error ExecutionTooEarly();
    error ExecutionTooLate();
}
