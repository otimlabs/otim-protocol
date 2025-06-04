// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {DepositAccount} from "../transient-contracts/DepositAccount.sol";

import {ICalculateDepositAddress} from "./interfaces/ICalculateDepositAddress.sol";

/// @title CalculateDepositAddress
/// @author Otim Labs, Inc.
/// @notice an abstract contract that calculates the address of a deposit account using Create2
abstract contract CalculateDepositAddress is ICalculateDepositAddress {
    /// @notice the prefix used to calculate the salt for the deposit account address
    bytes32 public constant SALT_PREFIX = keccak256("DepositAccount");

    /// @inheritdoc ICalculateDepositAddress
    function calculateDepositAddress(address owner, address depositor) public pure returns (address) {
        // include the depositor in the salt to ensure that the address is unique
        bytes32 salt = keccak256(abi.encode(SALT_PREFIX, depositor));
        // slither-disable-next-line too-many-digits
        return Create2.computeAddress(salt, keccak256(type(DepositAccount).creationCode), owner);
    }
}
