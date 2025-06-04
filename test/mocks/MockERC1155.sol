// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {ERC1155} from "@openzeppelin-contracts/token/ERC1155/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    constructor(string memory uri) ERC1155(uri) {}

    function mint(address account, uint256 id, uint256 amount, bytes memory data) public {
        _mint(account, id, amount, data);
    }
}
