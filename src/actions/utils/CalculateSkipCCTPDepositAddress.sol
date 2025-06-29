// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {SkipCCTPDepositAccount} from "../transient-contracts/SkipCCTPDepositAccount.sol";

import {ICalculateSkipCCTPDepositAddress} from "./interfaces/ICalculateSkipCCTPDepositAddress.sol";

/// @title CalculateSkipCCTPDepositAddress
/// @author Otim Labs, Inc.
/// @notice an abstract contract that calculates the address of a SkipCCTPDepositAccount using Create2
abstract contract CalculateSkipCCTPDepositAddress is ICalculateSkipCCTPDepositAddress {
    /// @notice the prefix used to calculate the salt for the deposit account address
    bytes32 public constant SALT = keccak256("SkipCCTPDepositAccount");

    /// @notice the USDC token address
    address public immutable usdcAddress;
    /// @notice the Skip Go CCTP relayer address
    address public immutable cctpRelayerAddress;
    /// @notice the CCTP TokenMinter address
    address public immutable tokenMinterAddress;
    /// @notice the SkipGoFeeOracle address
    address public immutable skipGoFeeOracleAddress;

    constructor(
        address usdcAddress_,
        address cctpRelayerAddress_,
        address tokenMinterAddress_,
        address skipGoFeeOracleAddress_
    ) {
        usdcAddress = usdcAddress_;
        cctpRelayerAddress = cctpRelayerAddress_;
        tokenMinterAddress = tokenMinterAddress_;
        skipGoFeeOracleAddress = skipGoFeeOracleAddress_;
    }

    /// @inheritdoc ICalculateSkipCCTPDepositAddress
    function calculateDepositAddress(
        address owner,
        address depositor,
        uint32 destinationDomain,
        bytes32 destinationMintRecipient
    ) public view returns (address) {
        // slither-disable-next-line too-many-digits
        return Create2.computeAddress(
            SALT,
            keccak256(
                abi.encodePacked(
                    type(SkipCCTPDepositAccount).creationCode,
                    abi.encode(
                        usdcAddress,
                        cctpRelayerAddress,
                        tokenMinterAddress,
                        skipGoFeeOracleAddress,
                        depositor,
                        destinationDomain,
                        destinationMintRecipient
                    )
                )
            ),
            owner
        );
    }
}
