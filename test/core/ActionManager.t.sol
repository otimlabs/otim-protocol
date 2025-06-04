// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/src/Test.sol";
import {Vm, VmSafe} from "forge-std/src/Vm.sol";

import {IAccessControl} from "@openzeppelin-contracts/access/IAccessControl.sol";

import {HelloWorldAction} from "../mocks/HelloWorldAction.sol";

import {IActionManager} from "../../src/core/interfaces/IActionManager.sol";
import {ActionManager} from "../../src/core/ActionManager.sol";

contract ActionManagerTest is Test {
    /// @notice test EOAs
    VmSafe.Wallet public owner = vm.createWallet("Owner");
    VmSafe.Wallet public killSwitchOwner = vm.createWallet("KillSwitchOwner");

    /// @notice test contracts
    ActionManager public target = new ActionManager(owner.addr);
    HelloWorldAction public helloWorldAction = new HelloWorldAction();

    /// @notice reusable Action vars
    address public action = address(helloWorldAction);
    bool public executable;

    /// @notice test ownership set up correctly
    function test_actionManager_constructor() public {
        vm.pauseGasMetering();

        vm.resumeGasMetering();
        target = new ActionManager(owner.addr);
        vm.pauseGasMetering();

        assertTrue(target.hasRole(target.DEFAULT_ADMIN_ROLE(), owner.addr));
        assertTrue(target.hasRole(target.KILL_SWITCH_ROLE(), owner.addr));
        assertEq(target.getRoleAdmin(target.KILL_SWITCH_ROLE()), target.DEFAULT_ADMIN_ROLE());
        assertEq(target.getRoleAdmin(target.DEFAULT_ADMIN_ROLE()), target.DEFAULT_ADMIN_ROLE());
    }

    /// @notice test access control for all functions
    function test_actionManager_accessControl() public {
        vm.pauseGasMetering();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), target.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.resumeGasMetering();
        target.addAction(action);
        vm.pauseGasMetering();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), target.DEFAULT_ADMIN_ROLE()
            )
        );
        target.removeAction(action);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), target.KILL_SWITCH_ROLE()
            )
        );
        target.lockAllActions();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), target.DEFAULT_ADMIN_ROLE()
            )
        );
        target.unlockAllActions();
    }

    /// @notice add Action flow
    function test_addAction_happyPath() public {
        vm.pauseGasMetering();

        vm.startPrank(owner.addr);

        vm.expectEmit();
        emit IActionManager.ActionAdded(action);

        vm.resumeGasMetering();
        target.addAction(action);
        vm.pauseGasMetering();

        executable = target.isExecutable(action);
        assertTrue(executable);

        vm.stopPrank();
    }

    /// @notice can't update Action metadata, need to remove then add again
    function test_addAction_alreadyExists() public {
        vm.pauseGasMetering();

        vm.startPrank(owner.addr);

        vm.expectEmit();
        emit IActionManager.ActionAdded(action);

        target.addAction(action);

        executable = target.isExecutable(action);
        assertTrue(executable);

        vm.expectRevert(abi.encodeWithSelector(IActionManager.AlreadyAdded.selector));
        vm.resumeGasMetering();
        target.addAction(action);
        vm.pauseGasMetering();

        vm.stopPrank();
    }

    /// @notice remove Action flow
    function test_removeAction_happyPath() public {
        vm.pauseGasMetering();

        vm.startPrank(owner.addr);

        target.addAction(action);

        vm.expectEmit();
        emit IActionManager.ActionRemoved(action);

        vm.resumeGasMetering();
        target.removeAction(action);
        vm.pauseGasMetering();

        executable = target.isExecutable(action);
        assertFalse(executable);

        vm.stopPrank();
    }

    /// @notice can't remove an already removed Action
    function test_removeAction_doesntExist() public {
        vm.pauseGasMetering();

        vm.startPrank(owner.addr);

        target.addAction(action);

        vm.expectEmit();
        emit IActionManager.ActionRemoved(action);

        target.removeAction(action);

        executable = target.isExecutable(action);
        assertFalse(executable);

        vm.expectRevert(abi.encodeWithSelector(IActionManager.AlreadyRemoved.selector));
        vm.resumeGasMetering();
        target.removeAction(action);
        vm.pauseGasMetering();

        executable = target.isExecutable(action);
        assertFalse(executable);

        vm.stopPrank();
    }

    /// @notice lock all Actions flow
    function test_lockAllActions_happyPath() public {
        vm.pauseGasMetering();

        vm.startPrank(owner.addr);

        target.addAction(action);

        executable = target.isExecutable(action);
        assertTrue(executable);

        vm.expectEmit();
        emit IActionManager.ActionsGloballyLocked();

        vm.resumeGasMetering();
        target.lockAllActions();
        vm.pauseGasMetering();

        executable = target.isExecutable(action);
        assertFalse(executable);

        vm.stopPrank();
    }

    /// @notice lock all Actions flow
    function test_lockAllActions_happyPath_killSwitchOwner() public {
        vm.pauseGasMetering();

        vm.prank(owner.addr);
        target.addAction(action);

        executable = target.isExecutable(action);
        assertTrue(executable);

        vm.startPrank(owner.addr);
        target.grantRole(target.KILL_SWITCH_ROLE(), killSwitchOwner.addr);
        vm.stopPrank();

        vm.startPrank(killSwitchOwner.addr);

        vm.expectEmit();
        emit IActionManager.ActionsGloballyLocked();

        vm.resumeGasMetering();
        target.lockAllActions();
        vm.pauseGasMetering();

        vm.stopPrank();

        bool globallyLocked = target.isGloballyLocked();
        assertTrue(globallyLocked);

        executable = target.isExecutable(action);
        assertFalse(executable);
    }

    /// @notice can't lock all Actions if already locked
    function test_lockAllActions_alreadyLocked() public {
        vm.pauseGasMetering();

        vm.startPrank(owner.addr);

        target.addAction(action);

        executable = target.isExecutable(action);
        assertTrue(executable);

        vm.expectEmit();
        emit IActionManager.ActionsGloballyLocked();

        target.lockAllActions();

        executable = target.isExecutable(action);
        assertFalse(executable);

        vm.expectRevert(abi.encodeWithSelector(IActionManager.AlreadyLocked.selector));
        vm.resumeGasMetering();
        target.lockAllActions();
        vm.pauseGasMetering();

        executable = target.isExecutable(action);
        assertFalse(executable);

        vm.stopPrank();
    }

    /// @notice unlock all Actions flow
    function test_unlockAllActions_happyPath() public {
        vm.pauseGasMetering();

        vm.startPrank(owner.addr);

        target.addAction(action);

        executable = target.isExecutable(action);
        assertTrue(executable);

        target.lockAllActions();

        executable = target.isExecutable(action);
        assertFalse(executable);

        vm.expectEmit();
        emit IActionManager.ActionsGloballyUnlocked();

        vm.resumeGasMetering();
        target.unlockAllActions();
        vm.pauseGasMetering();

        executable = target.isExecutable(action);
        assertTrue(executable);

        vm.stopPrank();
    }

    /// @notice can't unlock all Actions if already unlocked
    function test_unlockAllActions_alreadyUnlocked() public {
        vm.pauseGasMetering();

        vm.startPrank(owner.addr);

        target.addAction(action);

        executable = target.isExecutable(action);
        assertTrue(executable);

        vm.expectRevert(abi.encodeWithSelector(IActionManager.AlreadyUnlocked.selector));
        vm.resumeGasMetering();
        target.unlockAllActions();
        vm.pauseGasMetering();

        executable = target.isExecutable(action);
        assertTrue(executable);

        vm.stopPrank();
    }

    /// @notice test isGloballyLocked
    function test_isGloballyLocked() public {
        vm.pauseGasMetering();

        vm.startPrank(owner.addr);

        target.addAction(action);
        target.lockAllActions();

        vm.resumeGasMetering();
        bool globallyLocked = target.isGloballyLocked();
        vm.pauseGasMetering();
        assertTrue(globallyLocked);

        target.unlockAllActions();

        globallyLocked = target.isGloballyLocked();
        assertFalse(globallyLocked);

        vm.stopPrank();
    }
}
