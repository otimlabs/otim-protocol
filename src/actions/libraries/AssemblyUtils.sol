// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

/// @title AssemblyUtils
/// @author Otim Labs, Inc.
/// @notice A library providing low-level assembly utility functions
library AssemblyUtils {
    /// @notice Safely transfers a specified amount of ether to a target address with a gas limit
    /// @dev This utility avoids return bomb attacks by discarding the return value of the call
    /// @param target - The address to which the ether will be sent
    /// @param value - The amount of ether to send (in wei)
    /// @param gasLimit - The maximum amount of gas to use for the transfer
    /// @return success - whether the transfer was successful or not
    function safeTransferNoReturn(address target, uint256 value, uint256 gasLimit) internal returns (bool success) {
        assembly {
            // Call the target address with the specified value and gas limit
            // 1. Set the gas limit for the call
            // 2. Set the target to send ether to
            // 3. Set the value to send (in wei)
            // 4. Set the call data pointer to zero (no calldata needed)
            // 5. Set the call data size to zero (no calldata needed)
            // 6. Set the return data pointer to zero (discard return data)
            // 7. Set the return data size to zero (discard return data)
            success := call(gasLimit, target, value, 0, 0, 0, 0)
        }
    }
}
