// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

// contract that reverts with a return bomb error message
contract ReturnBombTarget {
    bytes public returnString;

    error ReturnBombError(bytes returnString);

    constructor(uint256 length) {
        bytes memory returnString_ = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            returnString_[i] = bytes1(0xff);
        }

        returnString = returnString_;
    }

    function returnBomb() external payable {
        revert ReturnBombError(returnString);
    }
}
