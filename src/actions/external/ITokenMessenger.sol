// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

interface ITokenMessenger {
    function depositForBurn(uint256 amount, uint32 destinationDomain, bytes32 mintRecipient, address burnToken)
        external
        returns (uint64 _nonce);
}
