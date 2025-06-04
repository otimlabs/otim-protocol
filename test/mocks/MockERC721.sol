// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {ERC721ConsecutiveEnumerableMock} from "@openzeppelin-contracts/mocks/token/ERC721ConsecutiveEnumerableMock.sol";

contract MockERC721 is ERC721ConsecutiveEnumerableMock {
    constructor(string memory name, string memory symbol, address[] memory receivers, uint96[] memory amounts)
        ERC721ConsecutiveEnumerableMock(name, symbol, receivers, amounts)
    {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}
