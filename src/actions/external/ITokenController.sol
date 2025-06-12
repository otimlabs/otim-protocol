// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

interface ITokenController {
    function burnLimitsPerMessage(address token) external view returns (uint256);
}
