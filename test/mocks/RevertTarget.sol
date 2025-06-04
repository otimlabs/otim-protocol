// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

// contract that reverts on receiving ether
contract RevertTarget {
    receive() external payable {
        revert();
    }
}
