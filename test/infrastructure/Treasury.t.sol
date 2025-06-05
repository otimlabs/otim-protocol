// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/src/Test.sol";
import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {BadERC20Mock} from "../mocks/BadERC20.sol";

import {RevertTarget} from "../mocks/RevertTarget.sol";

import {ITreasury} from "../../src/infrastructure/interfaces/ITreasury.sol";
import {Treasury} from "../../src/infrastructure/Treasury.sol";

contract TreasuryTest is Test {
    ITreasury public treasury = new Treasury(address(this));

    VmSafe.Wallet public target = vm.createWallet("target");

    ERC20Mock public USDT = new ERC20Mock();

    uint256 START_BALANCE = 1 ether;
    uint256 START_ERC20_BALANCE = 1_000_000_000;

    constructor() {
        vm.deal(address(treasury), START_BALANCE);
        USDT.mint(address(treasury), START_ERC20_BALANCE);
    }

    /// @notice test that deposit works as expected
    function test_deposit_happyPath() public {
        vm.pauseGasMetering();

        assertEq(address(treasury).balance, START_BALANCE);

        vm.resumeGasMetering();
        treasury.deposit{value: START_BALANCE}();
        vm.pauseGasMetering();

        assertEq(address(treasury).balance, START_BALANCE * 2);
    }

    /// @notice test that withdraw works as expected
    function test_withdraw_happyPath() public {
        vm.pauseGasMetering();

        assertEq(address(treasury).balance, START_BALANCE);
        assertEq(target.addr.balance, 0);

        vm.resumeGasMetering();
        treasury.withdraw(target.addr, START_BALANCE);
        vm.pauseGasMetering();

        assertEq(address(treasury).balance, 0);
        assertEq(target.addr.balance, START_BALANCE);
    }

    /// @notice test that withdraw fails with target = address(0)
    function test_withdraw_invalidTarget() public {
        vm.pauseGasMetering();

        vm.expectRevert(abi.encodeWithSelector(ITreasury.InvalidTarget.selector));

        vm.resumeGasMetering();
        treasury.withdraw(address(0), START_BALANCE);
        vm.pauseGasMetering();
    }

    /// @notice test that withdraw fails with Treasury insufficient balance
    function test_withdraw_insufficientBalance() public {
        vm.pauseGasMetering();

        address badRecipient = address(new RevertTarget());

        bytes memory result = "";
        vm.expectRevert(abi.encodeWithSelector(ITreasury.WithdrawalFailed.selector, result));

        vm.resumeGasMetering();
        treasury.withdraw(badRecipient, START_BALANCE);
        vm.pauseGasMetering();
    }

    /// @notice test that withdraw fails with reverting recipient
    function test_withdraw_transferFailed() public {
        vm.pauseGasMetering();

        RevertTarget badRecipient = new RevertTarget();

        bytes memory result = "";
        vm.expectRevert(abi.encodeWithSelector(ITreasury.WithdrawalFailed.selector, result));

        vm.resumeGasMetering();
        treasury.withdraw(address(badRecipient), START_BALANCE);
        vm.pauseGasMetering();
    }

    /// @notice test that withdrawERC20 works as expected
    function test_withdrawERC20_happyPath() public {
        vm.pauseGasMetering();

        assertEq(USDT.balanceOf(address(treasury)), START_ERC20_BALANCE);
        assertEq(USDT.balanceOf(target.addr), 0);

        vm.resumeGasMetering();
        treasury.withdrawERC20(address(USDT), target.addr, START_ERC20_BALANCE);
        vm.pauseGasMetering();

        assertEq(USDT.balanceOf(address(treasury)), 0);
        assertEq(USDT.balanceOf(target.addr), START_ERC20_BALANCE);
    }

    /// @notice test that withdrawERC20 with target = address(0) fails
    function test_withdrawERC20_invalidTarget() public {
        vm.pauseGasMetering();

        vm.expectRevert(abi.encodeWithSelector(ITreasury.InvalidTarget.selector));

        vm.resumeGasMetering();
        treasury.withdrawERC20(address(USDT), address(0), START_ERC20_BALANCE);
        vm.pauseGasMetering();
    }

    /// @notice test that withdrawERC20 with Treasury insufficient balance fails
    function test_withdrawERC20_insufficientBalance() public {
        vm.pauseGasMetering();

        vm.expectRevert(abi.encodeWithSelector(ITreasury.InsufficientBalance.selector));

        vm.resumeGasMetering();
        treasury.withdrawERC20(address(USDT), target.addr, START_ERC20_BALANCE + 1);
        vm.pauseGasMetering();
    }

    /// @notice test that withdrawERC20 with non-SafeERC20 token fails
    function test_withdrawERC20_transferFailed() public {
        vm.pauseGasMetering();

        BadERC20Mock badToken = new BadERC20Mock();

        badToken.mint(address(treasury), START_ERC20_BALANCE);

        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, badToken));

        vm.resumeGasMetering();
        treasury.withdrawERC20(address(badToken), target.addr, START_ERC20_BALANCE);
        vm.pauseGasMetering();
    }
}
