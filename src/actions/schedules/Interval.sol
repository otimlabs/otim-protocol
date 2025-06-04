// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IInterval, SCHEDULE_TYPEHASH} from "./interfaces/IInterval.sol";

/// @title Interval
/// @author Otim Labs, Inc.
/// @notice Interval schedule implementation
abstract contract Interval is IInterval {
    /// @inheritdoc IInterval
    function hash(Schedule memory schedule) public pure returns (bytes32) {
        return keccak256(
            abi.encode(SCHEDULE_TYPEHASH, schedule.startAt, schedule.startBy, schedule.interval, schedule.timeout)
        );
    }

    /// @inheritdoc IInterval
    function checkStart(Schedule memory schedule) public view override {
        if (block.timestamp < schedule.startAt) {
            revert ExecutionTooEarly();
        } else if (schedule.startBy < block.timestamp && schedule.startBy != 0) {
            revert ExecutionTooLate();
        }
    }

    /// @inheritdoc IInterval
    function checkInterval(Schedule memory schedule, uint256 lastExecuted) public view override {
        if (block.timestamp <= lastExecuted + schedule.interval) {
            revert ExecutionTooEarly();
        } else if (lastExecuted + schedule.interval + schedule.timeout < block.timestamp && schedule.timeout != 0) {
            revert ExecutionTooLate();
        }
    }
}
