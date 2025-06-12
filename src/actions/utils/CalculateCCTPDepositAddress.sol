// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {CCTPDepositAccount} from "../transient-contracts/CCTPDepositAccount.sol";

import {ITokenMessenger} from "../external/ITokenMessenger.sol";
import {ICalculateCCTPDepositAddress} from "./interfaces/ICalculateCCTPDepositAddress.sol";

/// @title CalculateCCTPDepositAddress
/// @author Otim Labs, Inc.
/// @notice an abstract contract that calculates the address of a CCTPDepositAccount using Create2
abstract contract CalculateCCTPDepositAddress is ICalculateCCTPDepositAddress {
    /// @notice the prefix used to calculate the salt for the deposit account address
    bytes32 public constant SALT_PREFIX = keccak256("CCTPDepositAccount");

    /// @notice the CCTP TokenMessenger contract
    ITokenMessenger public immutable tokenMessenger;

    constructor(address tokenMessengerAddress) {
        tokenMessenger = ITokenMessenger(tokenMessengerAddress);
    }

    /// @inheritdoc ICalculateCCTPDepositAddress
    function calculateCCTPDepositAddress(address owner, address depositor) public view returns (address) {
        // include the depositor in the salt to ensure that the address is unique
        bytes32 salt = keccak256(abi.encode(SALT_PREFIX, depositor));
        // slither-disable-next-line too-many-digits
        return Create2.computeAddress(
            salt,
            keccak256(abi.encodePacked(type(CCTPDepositAccount).creationCode, abi.encode(address(tokenMessenger)))),
            owner
        );
    }
}
