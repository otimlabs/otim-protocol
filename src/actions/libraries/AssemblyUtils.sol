// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

/// @title AssemblyUtils
/// @author Otim Labs, Inc.
/// @notice a library providing low-level assembly utility functions
library AssemblyUtils {
    /// @notice safely transfers a specified amount of ether to a target address with a gas limit
    /// @dev this utility avoids return bomb attacks by discarding the return value of the call
    /// @param target - the address to which the ether will be sent
    /// @param value - the amount of ether to send (in wei)
    /// @param gasLimit - the maximum amount of gas to use for the transfer
    /// @return success - whether the transfer was successful or not
    function safeTransferNoReturn(address target, uint256 value, uint256 gasLimit) internal returns (bool success) {
        assembly {
            // call the target address with the specified value and gas limit
            // 1. set the gas limit for the call
            // 2. set the target to send ether to
            // 3. set the value to send (in wei)
            // 4. set the call data pointer to zero (no calldata needed)
            // 5. set the call data size to zero (no calldata needed)
            // 6. set the return data pointer to zero (discard return data)
            // 7. set the return data size to zero (discard return data)
            success := call(gasLimit, target, value, 0, 0, 0, 0)
        }
    }

    /// @notice safely calls a target contract with a gas limit and return data size limit
    /// @dev this utility avoids return bomb attacks by limiting the size of the return data
    /// @param target - the address to call
    /// @param value - the amount of ether to send (in wei)
    /// @param gasLimit - the maximum amount of gas to use for the call
    /// @param returnSizeLimit - the maximum size of the return data (in bytes)
    /// @param data - the call data to send to the target contract
    /// @return success - whether the transfer was successful or not
    /// @return result - the return data from the call, limited to `returnLimit` bytes
    function safeCallLimitReturn(
        address target,
        uint256 value,
        uint256 gasLimit,
        uint16 returnSizeLimit,
        bytes memory data
    ) internal returns (bool success, bytes memory result) {
        // allocate `returnSizeLimit` bytes of memory for the return data
        result = new bytes(returnSizeLimit);

        assembly {
            // call the target address with the specified value and gas limit
            // 1. set the gas limit for the call
            // 2. set the target to send ether to
            // 3. set the value to send (in wei)
            // 4. set the call data pointer to start of `data` buffer
            // 5. set the call data size to the length of `data`
            // 6. set the return data pointer to zero (manually copy return data)
            // 7. set the return data size to zero (manually copy return data)
            success := call(gasLimit, target, value, add(data, 0x20), mload(data), 0, 0)

            // get the true size of the return data
            let size := returndatasize()

            // set `size` to `returnSizeLimit` if the true size exceeds the limit
            if gt(size, returnSizeLimit) { size := returnSizeLimit }
            // allocate `size` bytes of memory for the return data
            mstore(result, size)

            // copy `size` bytes of return data from the call to the result buffer
            returndatacopy(add(result, 0x20), 0, size)
        }
    }
}
