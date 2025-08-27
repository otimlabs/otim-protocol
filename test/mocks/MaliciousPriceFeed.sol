// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink-contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title MaliciousPriceFeed
/// @notice A mock price feed that always reverts for testing security scenarios
contract MaliciousPriceFeed is AggregatorV3Interface {
    function latestRoundData()
        external
        pure
        returns (
            uint80, /* roundId */
            int256, /* answer */
            uint256, /* startedAt */
            uint256, /* updatedAt */
            uint80 /* answeredInRound */
        )
    {
        revert("Malicious feed always reverts");
    }

    function getRoundData(uint80 /* _roundId */ )
        external
        pure
        returns (
            uint80, /* roundId */
            int256, /* answer */
            uint256, /* startedAt */
            uint256, /* updatedAt */
            uint80 /* answeredInRound */
        )
    {
        revert("Malicious feed always reverts");
    }

    function decimals() external pure returns (uint8) {
        revert("Malicious feed always reverts");
    }

    function version() external pure returns (uint256) {
        revert("Malicious feed always reverts");
    }

    function description() external pure returns (string memory) {
        revert("Malicious feed always reverts");
    }
}
