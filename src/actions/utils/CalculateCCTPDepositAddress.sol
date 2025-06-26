// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {CCTPDepositAccount} from "../transient-contracts/CCTPDepositAccount.sol";

import {ICCTPRelayer} from "@skip-go-evm-contracts/CCTPRelayer/src/interfaces/ICCTPRelayer.sol";
import {ICalculateCCTPDepositAddress} from "./interfaces/ICalculateCCTPDepositAddress.sol";

/// @title CalculateCCTPDepositAddress
/// @author Otim Labs, Inc.
/// @notice an abstract contract that calculates the address of a CCTPDepositAccount using Create2
abstract contract CalculateCCTPDepositAddress is ICalculateCCTPDepositAddress {
    /// @notice the prefix used to calculate the salt for the deposit account address
    bytes32 public constant SALT_PREFIX = keccak256("CCTPDepositAccount");

    /// @notice the USDC token address
    address public immutable usdcAddress;
    /// @notice the SkipGo CCTP relayer address
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

    /// @inheritdoc ICalculateCCTPDepositAddress
    function calculateDepositAddress(
        address owner,
        address depositor,
        uint32 destinationDomain,
        bytes32 destinationMintRecipient
    ) public view returns (address) {
        // slither-disable-next-line too-many-digits
        return Create2.computeAddress(
            SALT_PREFIX,
            keccak256(
                abi.encodePacked(
                    type(CCTPDepositAccount).creationCode,
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
