// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {ERC721} from "@openzeppelin-contracts/token/ERC721/ERC721.sol";
import {ERC721Consecutive} from "@openzeppelin-contracts/token/ERC721/extensions/ERC721Consecutive.sol";
import {ERC721Enumerable} from "@openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract ERC721ConsecutiveEnumerableMock is ERC721Consecutive, ERC721Enumerable {
    constructor(string memory name, string memory symbol, address[] memory receivers, uint96[] memory amounts)
        ERC721(name, symbol)
    {
        for (uint256 i = 0; i < receivers.length; ++i) {
            _mintConsecutive(receivers[i], amounts[i]);
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _ownerOf(uint256 tokenId) internal view virtual override(ERC721, ERC721Consecutive) returns (address) {
        return super._ownerOf(tokenId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        virtual
        override(ERC721Consecutive, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 amount) internal virtual override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, amount);
    }
}

contract MockERC721 is ERC721ConsecutiveEnumerableMock {
    constructor(string memory name, string memory symbol, address[] memory receivers, uint96[] memory amounts)
        ERC721ConsecutiveEnumerableMock(name, symbol, receivers, amounts)
    {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}
