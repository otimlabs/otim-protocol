// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

contract MockTarget {
    receive() external payable {}

    function helloWorldNonPayable() public pure returns (string memory) {
        return "Hello, World!";
    }

    function helloWorldPayable() public payable returns (string memory) {
        return "Hello, World!";
    }
}
