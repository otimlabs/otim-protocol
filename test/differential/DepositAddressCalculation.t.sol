// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/src/Test.sol";

import {SweepDepositAccountAction} from "../../src/actions/SweepDepositAccountAction.sol";
import {SweepDepositAccountERC20Action} from "../../src/actions/SweepDepositAccountERC20Action.sol";

contract DepositAddressCalculation is Test {
    SweepDepositAccountAction public sweepDepositAccountAction =
        new SweepDepositAccountAction(address(0), address(0), 0);

    SweepDepositAccountERC20Action public sweepDepositAccountERC20Action =
        new SweepDepositAccountERC20Action(address(0), address(0), 0);

    /// @notice make sure SweepDepositAccountAction and SweepERC20DepositAccountAction calculate the same deposit address given the same input
    function testFuzz_depositAccountAddressCalculation(address owner, address depositor) public view {
        address depositAccountAddress = sweepDepositAccountAction.calculateDepositAddress(owner, depositor);

        address erc20DepositAccountAddress = sweepDepositAccountERC20Action.calculateDepositAddress(owner, depositor);

        assertEq(depositAccountAddress, erc20DepositAccountAddress);
    }
}
