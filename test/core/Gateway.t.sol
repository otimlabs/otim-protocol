// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

// forge test suite
import {Vm, VmSafe} from "forge-std/src/Vm.sol";

// test helper contract
import {InstructionTestContext} from "../utils/InstructionTestContext.sol";

import {IGateway} from "../../src/core/interfaces/IGateway.sol";

import {IInterval} from "../../src/actions/schedules/interfaces/IInterval.sol";
import {IOtimFee} from "../../src/actions/fee-models/interfaces/IOtimFee.sol";

import {ITransferAction} from "../../src/actions/interfaces/ITransferAction.sol";
import {TransferAction} from "../../src/actions/TransferAction.sol";

contract GatewayTest is InstructionTestContext {
    constructor() {
        /// @notice Action setup
        TransferAction transfer = new TransferAction(address(0), address(0), 0);

        actionManager.addAction(address(transfer));

        /// @notice Instruction defaults
        DEFAULT_ACTION = address(transfer);
        DEFAULT_ARGS = abi.encode(
            ITransferAction.Transfer({
                target: payable(address(1)),
                value: 100,
                gasLimit: 21_000,
                schedule: IInterval.Schedule({startAt: 0, startBy: 0, interval: 0, timeout: 0}),
                fee: IOtimFee.Fee({token: address(0), maxBaseFeePerGas: 0, maxPriorityFeePerGas: 0, executionFee: 0})
            })
        );
    }

    /// @notice test that isDelegated returns true when user is delegated
    function test_isDelegated_true() public view {
        assertTrue(gateway.isDelegated(address(user)));
    }

    /// @notice test that isDelegated returns false when user is not delegated
    function test_isDelegated_false() public {
        // delegate the user to a different address
        vm.signAndAttachDelegation(address(123), userEOA.privateKey);

        assertFalse(gateway.isDelegated(address(user)));
    }

    /// @notice test that safeExecuteInstruction succeeds when user is delegated
    function test_safeExecuteInstruction_happyPath() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.resumeGasMetering();
        gateway.safeExecuteInstruction(address(user), instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that safeExecuteInstruction (with no signature) succeeds when user is delegated
    function test_safeExecuteInstruction_happyPath_noSig() public {
        vm.pauseGasMetering();

        buildInstruction();

        gateway.safeExecuteInstruction(address(user), instruction, instructionSig);

        skip(1);

        vm.resumeGasMetering();
        gateway.safeExecuteInstruction(address(user), instruction);
        vm.pauseGasMetering();
    }

    /// @notice test that safeExecuteInstruction fails when user is not delegated
    function test_safeExecuteInstruction_targetNotDelegated() public {
        vm.pauseGasMetering();

        buildInstruction();

        // delegate the user to a different address
        vm.signAndAttachDelegation(address(123), userEOA.privateKey);

        vm.expectRevert(abi.encodeWithSelector(IGateway.TargetNotDelegated.selector));

        vm.resumeGasMetering();
        gateway.safeExecuteInstruction(address(user), instruction, instructionSig);
        vm.pauseGasMetering();
    }

    /// @notice test that safeExecuteInstruction (no signature) fails when user is not delegated
    function test_safeExecuteInstruction_targetNotDelegated_noSig() public {
        vm.pauseGasMetering();

        buildInstruction();

        gateway.safeExecuteInstruction(address(user), instruction, instructionSig);

        skip(1);

        // delegate the user to a different address
        vm.signAndAttachDelegation(address(123), userEOA.privateKey);

        vm.expectRevert(abi.encodeWithSelector(IGateway.TargetNotDelegated.selector));

        vm.resumeGasMetering();
        gateway.safeExecuteInstruction(address(user), instruction);
        vm.pauseGasMetering();
    }

    /// @notice test that safeDeactivateInstruction succeeds when user is delegated
    function test_safeDeactivateInstruction_happyPath() public {
        vm.pauseGasMetering();

        buildInstruction();

        vm.resumeGasMetering();
        gateway.safeDeactivateInstruction(address(user), deactivation, deactivationSig);
        vm.pauseGasMetering();
    }

    /// @notice test that safeDeactivateInstruction fails when user is not delegated
    function test_safeDeactivateInstruction_targetNotDelegated() public {
        vm.pauseGasMetering();

        buildInstruction();

        // delegate the user to a different address
        vm.signAndAttachDelegation(address(123), userEOA.privateKey);

        vm.expectRevert(abi.encodeWithSelector(IGateway.TargetNotDelegated.selector));

        vm.resumeGasMetering();
        gateway.safeDeactivateInstruction(address(user), deactivation, deactivationSig);
        vm.pauseGasMetering();
    }
}
