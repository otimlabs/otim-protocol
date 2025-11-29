// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/src/Test.sol";

import {OtimDelegate} from "../../src/OtimDelegate.sol";

import {FeeTokenRegistry} from "../../src/infrastructure/FeeTokenRegistry.sol";
import {Treasury} from "../../src/infrastructure/Treasury.sol";

import {TransferAction} from "../../src/actions/TransferAction.sol";
import {TransferERC20Action} from "../../src/actions/TransferERC20Action.sol";
import {RefuelAction} from "../../src/actions/RefuelAction.sol";
import {RefuelERC20Action} from "../../src/actions/RefuelERC20Action.sol";
import {UniswapV3ExactInputAction} from "../../src/actions/UniswapV3ExactInputAction.sol";
import {DeactivateInstructionAction} from "../../src/actions/DeactivateInstructionAction.sol";
import {TransferOnceAction} from "../../src/actions/TransferOnceAction.sol";
import {TransferERC20OnceAction} from "../../src/actions/TransferERC20OnceAction.sol";
import {SweepAction} from "../../src/actions/SweepAction.sol";
import {SweepERC20Action} from "../../src/actions/SweepERC20Action.sol";
import {CallOnceAction} from "../../src/actions/CallOnceAction.sol";
import {SweepCCTPAction} from "../../src/actions/SweepCCTPAction.sol";
import {TransferCCTPAction} from "../../src/actions/TransferCCTPAction.sol";
import {SweepUniswapV3Action} from "../../src/actions/SweepUniswapV3Action.sol";
import {DepositERC4626Action} from "../../src/actions/DepositERC4626Action.sol";
import {SweepDepositERC4626Action} from "../../src/actions/SweepDepositERC4626Action.sol";
import {WithdrawERC4626Action} from "../../src/actions/WithdrawERC4626Action.sol";
import {SweepWithdrawERC4626Action} from "../../src/actions/SweepWithdrawERC4626Action.sol";

contract DeploymentAddressesTest is Test {
    // expected core addresses
    address constant EXPECTED_OTIM_DELEGATE_ADDRESS = 0x1292349F9D9179286b831AF9a7F1F7d3E24ACd17;

    // expected infrastructure addresses
    address constant EXPECTED_FEE_TOKEN_REGISTRY_ADDRESS = 0xaB0d5Af339e4D3E986E5b1b0F936e700c211540b;
    address constant EXPECTED_TREASURY_ADDRESS = 0x347e715405cDD0B272FC9f681f30A99DFe5702DE;

    // expected action addresses
    address constant EXPECTED_TRANSFER_ACTION_ADDRESS = 0x8c6935D1000dFF1f19de14636B0e67B3cD9921dC;
    address constant EXPECTED_TRANSFER_ERC20_ACTION_ADDRESS = 0x0860117A7A5930C7970f4a4E0CDC7D37b70E4F46;
    address constant EXPECTED_REFUEL_ACTION_ADDRESS = 0xd85576b4B9f9552292A0B7eBCa5f8B8f48a6637f;
    address constant EXPECTED_REFUEL_ERC20_ACTION_ADDRESS = 0xCFA692c1f99008de0B4AA2c8ed49afD8971ddad9;
    address constant EXPECTED_UNISWAP_V3_EXACT_INPUT_ACTION_ADDRESS = 0xD1e7Ef6fd641ff48678B1A8f6c815a24e5D14cB4;
    address constant EXPECTED_DEACTIVATE_INSTRUCTION_ACTION_ADDRESS = 0xd6EDb2C598603E77424145E58fb5F4D49092C46B;
    address constant EXPECTED_TRANSFER_ONCE_ACTION_ADDRESS = 0x24364bc3C227515BD2f263b63b1C381F86Cc11dB;
    address constant EXPECTED_TRANSFER_ONCE_ERC20_ACTION_ADDRESS = 0x007c835EF7A99878Ca2cB75F9c59bF996527EE3a;
    address constant EXPECTED_SWEEP_ACTION_ADDRESS = 0xCb526Dd98445D70D1718914e76Ec023e22808Bf0;
    address constant EXPECTED_SWEEP_ERC20_ACTION_ADDRESS = 0x85dCC0E70aD4288b4540D1A5f3Ba49b7934c2E88;
    address constant EXPECTED_CALL_ONCE_ACTION_ADDRESS = 0xCD6cBec852F898C403dC9BFB080aD04b9Fb4Cf8a;
    address constant EXPECTED_SWEEP_CCTP_ACTION_ADDRESS = 0x8794e8ab128C0262f3b14D858d1e026219078d06;
    address constant EXPECTED_TRANSFER_CCTP_ACTION_ADDRESS = 0x5C7aA487188CBbeFcdb83814C7c8530FAC4f8f67;
    address constant EXPECTED_SWEEP_UNISWAP_V3_ACTION_ADDRESS = 0xb163911E78663533384019C93e14f5F03ACD43E5;
    address constant EXPECTED_DEPOSIT_ERC4626_ACTION_ADDRESS = 0x2Af953573eba54D70be580ce60a6226B8491010E;
    address constant EXPECTED_SWEEP_DEPOSIT_ERC4626_ACTION_ADDRESS = 0x0B7B5eB78e9823A886E886194a49aF9aCfb430b3;
    address constant EXPECTED_WITHDRAW_ERC4626_ACTION_ADDRESS = 0x819a73E0C7a8678e209398176C9C74aba1186DC2;
    address constant EXPECTED_SWEEP_WITHDRAW_ERC4626_ACTION_ADDRESS = 0x745f88d2A24a788d4d2ee24166AD8416417128A9;

    ////////////////////
    // Core addresses //
    ////////////////////

    /// @dev this implicitly tests that Gateway, InstructionStorage, and ActionManager addresses are correct
    function test_otimDelegate_deployedAddress() public {
        address deployed = address(new OtimDelegate{salt: bytes32(0)}(address(0)));
        assertEq(deployed, EXPECTED_OTIM_DELEGATE_ADDRESS);
    }

    //////////////////////////////
    // Infrastructure addresses //
    //////////////////////////////

    function test_feeTokenRegistry_deployedAddress() public {
        address deployed = address(new FeeTokenRegistry{salt: bytes32(0)}(address(1))); // Ownable constructor requires non-zero address
        assertEq(deployed, EXPECTED_FEE_TOKEN_REGISTRY_ADDRESS);
    }

    function test_treasury_deployedAddress() public {
        address deployed = address(new Treasury{salt: bytes32(0)}(address(1))); // Ownable constructor requires non-zero address
        assertEq(deployed, EXPECTED_TREASURY_ADDRESS);
    }

    //////////////////////
    // Action addresses //
    //////////////////////

    function test_transferAction_deployedAddress() public {
        address deployed = address(new TransferAction{salt: bytes32(0)}(address(0), address(0), 0));
        assertEq(deployed, EXPECTED_TRANSFER_ACTION_ADDRESS);
    }

    function test_transferERC20Action_deployedAddress() public {
        address deployed = address(new TransferERC20Action{salt: bytes32(0)}(address(0), address(0), 0));
        assertEq(deployed, EXPECTED_TRANSFER_ERC20_ACTION_ADDRESS);
    }

    function test_refuelAction_deployedAddress() public {
        address deployed = address(new RefuelAction{salt: bytes32(0)}(address(0), address(0), 0));
        assertEq(deployed, EXPECTED_REFUEL_ACTION_ADDRESS);
    }

    function test_refuelERC20Action_deployedAddress() public {
        address deployed = address(new RefuelERC20Action{salt: bytes32(0)}(address(0), address(0), 0));
        assertEq(deployed, EXPECTED_REFUEL_ERC20_ACTION_ADDRESS);
    }

    function test_uniswapV3ExactInputAction_deployedAddress() public {
        address deployed = address(
            new UniswapV3ExactInputAction{salt: bytes32(0)}(
                address(0), address(0), address(0), address(0), address(0), 0
            )
        );

        assertEq(deployed, EXPECTED_UNISWAP_V3_EXACT_INPUT_ACTION_ADDRESS);
    }

    function test_deactivateInstructionAction_deployedAddress() public {
        address deployed =
            address(new DeactivateInstructionAction{salt: bytes32(0)}(address(0), address(0), address(0), 0));
        assertEq(deployed, EXPECTED_DEACTIVATE_INSTRUCTION_ACTION_ADDRESS);
    }

    function test_transferOnceAction_deployedAddress() public {
        address deployed = address(new TransferOnceAction{salt: bytes32(0)}(address(0), address(0), 0));
        assertEq(deployed, EXPECTED_TRANSFER_ONCE_ACTION_ADDRESS);
    }

    function test_transferOnceERC20Action_deployedAddress() public {
        address deployed = address(new TransferERC20OnceAction{salt: bytes32(0)}(address(0), address(0), 0));
        assertEq(deployed, EXPECTED_TRANSFER_ONCE_ERC20_ACTION_ADDRESS);
    }

    function test_sweepAction_deployedAddress() public {
        address deployed = address(new SweepAction{salt: bytes32(0)}(address(0), address(0), 0));
        assertEq(deployed, EXPECTED_SWEEP_ACTION_ADDRESS);
    }

    function test_sweepERC20Action_deployedAddress() public {
        address deployed = address(new SweepERC20Action{salt: bytes32(0)}(address(0), address(0), 0));
        assertEq(deployed, EXPECTED_SWEEP_ERC20_ACTION_ADDRESS);
    }

    function test_callOnceAction_deployedAddress() public {
        address deployed = address(new CallOnceAction{salt: bytes32(0)}(address(0), address(0), address(0), 0));
        assertEq(deployed, EXPECTED_CALL_ONCE_ACTION_ADDRESS);
    }

    function test_sweepCCTPAction_deployedAddress() public {
        address deployed =
            address(new SweepCCTPAction{salt: bytes32(0)}(address(0), address(0), address(0), address(0), 0));
        assertEq(deployed, EXPECTED_SWEEP_CCTP_ACTION_ADDRESS);
    }

    function test_transferCCTPAction_deployedAddress() public {
        address deployed =
            address(new TransferCCTPAction{salt: bytes32(0)}(address(0), address(0), address(0), address(0), 0));
        assertEq(deployed, EXPECTED_TRANSFER_CCTP_ACTION_ADDRESS);
    }

    function test_sweepUniswapV3Action_deployedAddress() public {
        address deployed = address(
            new SweepUniswapV3Action{salt: bytes32(0)}(address(0), address(0), address(0), address(0), address(0), 0)
        );
        assertEq(deployed, EXPECTED_SWEEP_UNISWAP_V3_ACTION_ADDRESS);
    }

    function test_depositERC4626Action_deployedAddress() public {
        address deployed = address(new DepositERC4626Action{salt: bytes32(0)}(address(0), address(0), 0));
        assertEq(deployed, EXPECTED_DEPOSIT_ERC4626_ACTION_ADDRESS);
    }

    function test_sweepDepositERC4626Action_deployedAddress() public {
        address deployed = address(new SweepDepositERC4626Action{salt: bytes32(0)}(address(0), address(0), 0));
        assertEq(deployed, EXPECTED_SWEEP_DEPOSIT_ERC4626_ACTION_ADDRESS);
    }

    function test_withdrawERC4626Action_deployedAddress() public {
        address deployed = address(new WithdrawERC4626Action{salt: bytes32(0)}(address(0), address(0), 0));
        assertEq(deployed, EXPECTED_WITHDRAW_ERC4626_ACTION_ADDRESS);
    }

    function test_sweepWithdrawERC4626Action_deployedAddress() public {
        address deployed = address(new SweepWithdrawERC4626Action{salt: bytes32(0)}(address(0), address(0), 0));
        assertEq(deployed, EXPECTED_SWEEP_WITHDRAW_ERC4626_ACTION_ADDRESS);
    }
}
