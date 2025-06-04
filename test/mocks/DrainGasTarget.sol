// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

// contract that drains gas on receiving ether
contract DrainGasTarget {
    receive() external payable {
        // drain gas to simulate a failed transfer
        while (true) {}
    }
}
