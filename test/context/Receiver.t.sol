// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {InstructionTestContext} from "../utils/InstructionTestContext.sol";

import {MockERC1155} from "../mocks/MockERC1155.sol";
import {MockERC721} from "../mocks/MockERC721.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";

contract ReceiverTest is InstructionTestContext {
    MockERC721 public erc721 = new MockERC721("ERC721", "ERC721", new address[](0), new uint96[](0));
    MockERC1155 public erc1155 = new MockERC1155("ERC1155");

    VmSafe.Wallet public otherEOA = vm.createWallet("otherEOA");
    IOtimDelegate public other = IOtimDelegate(otherEOA.addr);

    constructor() {
        vm.signAndAttachDelegation(address(delegate), otherEOA.privateKey);
    }

    /// @notice test EOA receives ether
    function test_receiveEther() public {
        vm.pauseGasMetering();

        uint256 value_ = 100;

        vm.deal(address(user), 0);
        vm.deal(address(other), value_);

        assertEq(address(user).balance, 0);
        assertEq(address(other).balance, value_);

        vm.resumeGasMetering();
        vm.prank(address(other));
        (bool success,) = address(user).call{value: value_}("");
        vm.pauseGasMetering();

        assertTrue(success);
        assertEq(address(user).balance, value_);
    }

    /// @notice test EOA receives ERC721 tokens with safeTransferFrom
    function test_receiveERC721() public {
        vm.pauseGasMetering();

        uint256 id = 1;

        erc721.mint(address(other), id);

        assertEq(erc721.ownerOf(id), address(other));

        vm.resumeGasMetering();
        vm.prank(address(other));
        erc721.safeTransferFrom(address(other), address(user), id);
        vm.pauseGasMetering();

        assertEq(erc721.ownerOf(id), address(user));
    }

    /// @notice test EOA receives ERC1155 tokens with safeTransferFrom
    function test_receiveERC1155() public {
        vm.pauseGasMetering();

        uint256 id = 1;
        uint256 amount = 1;

        erc1155.mint(address(other), id, amount, "");

        assertEq(erc1155.balanceOf(address(other), id), amount);
        assertEq(erc1155.balanceOf(address(user), id), 0);

        vm.resumeGasMetering();
        vm.prank(address(other));
        erc1155.safeTransferFrom(address(other), address(user), id, amount, "");
        vm.pauseGasMetering();

        assertEq(erc1155.balanceOf(address(other), id), 0);
        assertEq(erc1155.balanceOf(address(user), id), amount);
    }

    /// @notice test EOA receives a batch of ERC1155 tokens with safeBatchTransferFrom
    function test_receiveBatchERC1155() public {
        vm.pauseGasMetering();

        uint256 id1 = 1;
        uint256 id2 = 2;
        uint256 id3 = 3;

        uint256 value1 = 1;
        uint256 value2 = 10;
        uint256 value3 = 100;

        erc1155.mint(address(other), id1, value1, "");
        erc1155.mint(address(other), id2, value2, "");
        erc1155.mint(address(other), id3, value3, "");

        assertEq(erc1155.balanceOf(address(other), id1), value1);
        assertEq(erc1155.balanceOf(address(other), id2), value2);
        assertEq(erc1155.balanceOf(address(other), id3), value3);

        assertEq(erc1155.balanceOf(address(user), id1), 0);
        assertEq(erc1155.balanceOf(address(user), id2), 0);
        assertEq(erc1155.balanceOf(address(user), id3), 0);

        uint256[] memory ids = new uint256[](3);
        ids[0] = id1;
        ids[1] = id2;
        ids[2] = id3;

        uint256[] memory values = new uint256[](3);
        values[0] = value1;
        values[1] = value2;
        values[2] = value3;

        vm.resumeGasMetering();
        vm.prank(address(other));
        erc1155.safeBatchTransferFrom(address(other), address(user), ids, values, "");
        vm.pauseGasMetering();

        assertEq(erc1155.balanceOf(address(other), id1), 0);
        assertEq(erc1155.balanceOf(address(other), id2), 0);
        assertEq(erc1155.balanceOf(address(other), id3), 0);

        assertEq(erc1155.balanceOf(address(user), id1), value1);
        assertEq(erc1155.balanceOf(address(user), id2), value2);
        assertEq(erc1155.balanceOf(address(user), id3), value3);
    }
}
