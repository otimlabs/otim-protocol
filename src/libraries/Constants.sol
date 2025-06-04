// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

/// @title Constants
/// @author Otim Labs, Inc.
/// @notice a library defining constants used throughout the protocol
library Constants {
    /// @notice the EIP-712 signature prefix
    bytes2 public constant EIP712_PREFIX = 0x1901;

    /// @notice the EIP-7702 delegation designator prefix
    bytes3 public constant EIP7702_PREFIX = 0xef0100;
}
