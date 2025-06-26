// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ISkipGoFeeOracle} from "./interfaces/ISkipGoFeeOracle.sol";

/// @title SkipGoFeeOracle
/// @author Otim Labs, Inc.
/// @notice an oracle that stores SkipGo fees for transferring USDC to certain destination chains
contract SkipGoFeeOracle is ISkipGoFeeOracle, Ownable {
    /// @notice mapping to store fees for each destination domain
    mapping(uint32 => uint256) private fees;

    constructor(address owner) Ownable(owner) {}

    /// @inheritdoc ISkipGoFeeOracle
    function setFee(uint32 destinationDomain, uint256 fee) external onlyOwner {
        if (fee == 0) revert FeeCannotBeZero();

        fees[destinationDomain] = fee;
    }

    /// @inheritdoc ISkipGoFeeOracle
    function removeFee(uint32 destinationDomain) external onlyOwner {
        delete fees[destinationDomain];
    }

    /// @inheritdoc ISkipGoFeeOracle
    function getFee(uint32 destinationDomain) external view returns (uint256) {
        uint256 fee = fees[destinationDomain];

        if (fee == 0) revert RouteNotSupported();

        return fee;
    }
}
