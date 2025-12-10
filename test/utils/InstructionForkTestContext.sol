// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/src/Test.sol";
import {VmSafe} from "forge-std/src/Vm.sol";

import {Constants} from "../../src/libraries/Constants.sol";
import {InstructionLib} from "../../src/libraries/Instruction.sol";

import {OtimDelegate} from "../../src/OtimDelegate.sol";
import {Gateway} from "../../src/core/Gateway.sol";
import {InstructionStorage} from "../../src/core/InstructionStorage.sol";
import {ActionManager} from "../../src/core/ActionManager.sol";

import {IOtimDelegate} from "../../src/IOtimDelegate.sol";
import {IAction} from "../../src/actions/interfaces/IAction.sol";

abstract contract InstructionForkTestContext is Test {
    using InstructionLib for InstructionLib.Instruction;
    using InstructionLib for InstructionLib.InstructionDeactivation;

    /// @notice Mainnet Steakhouse USDC vault
    address public constant MAINNET_STEAKHOUSE_USDC_VAULT = address(0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB);

    /// @notice Mainnet token addresses
    address public constant MAINNET_WETH9 = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant MAINNET_USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    /// @notice Mainnet USDC whale for spoofing test balance
    address public constant MAINNET_USDC_WHALE = address(0xEe7aE85f2Fe2239E27D9c1E23fFFe168D63b4055);

    /// @notice Sepolia token addresses
    address public constant SEPOLIA_WETH9 = address(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);
    address public constant SEPOLIA_USDC = address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);

    /// @notice Sepolia USDC whale for spoofing test balance
    address public constant SEPOLIA_USDC_WHALE = address(0x1fD9611f009fcB8Bec0A4854FDcA0832DfdB04E3);

    /// @notice Sepolia Uniswap V3 addresses
    address public constant SEPOLIA_UNIVERSAL_ROUTER = address(0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD);
    address public constant SEPOLIA_V3_FACTORY = address(0x0227628f3F023bb0B980b67D528571c95c6DaC1c);

    /// @notice Sepolia CCTP V1 addresses
    address public constant SEPOLIA_TOKEN_MESSENGER = address(0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5);
    address public constant SEPOLIA_TOKEN_MINTER = address(0xE997d7d2F6E065a9A93Fa2175E878Fb9081F1f0A);

    /// @notice Sepolia CCTP V2 addresses
    address public constant SEPOLIA_TOKEN_MESSENGER_V2 = address(0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA);
    address public constant SEPOLIA_MESSAGE_TRANSMITTER_V2 = address(0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275);
    address public constant SEPOLIA_TOKEN_MINTER_V2 = address(0xE997d7d2F6E065a9A93Fa2175E878Fb9081F1f0A);

    /// @notice test Core contracts
    OtimDelegate public delegate = new OtimDelegate(address(this));

    Gateway public gateway = Gateway(address(delegate.gateway()));
    InstructionStorage public instructionStorage = InstructionStorage(address(delegate.instructionStorage()));
    ActionManager public actionManager = ActionManager(address(delegate.actionManager()));

    /// @notice user EOA
    VmSafe.Wallet public userEOA = vm.createWallet("userEOA");

    /// @notice delegated user
    IOtimDelegate public user = IOtimDelegate(userEOA.addr);

    uint256 public USER_START_BALANCE = 1 ether;

    /// @notice reusable Instruction vars
    InstructionLib.Instruction public instruction;
    bytes32 public instructionId;
    bytes32 public instructionHash;
    InstructionLib.Signature public instructionSig;

    /// @notice reusable signature vars
    InstructionLib.InstructionDeactivation public deactivation;
    bytes32 public deactivationHash;
    InstructionLib.Signature public deactivationSig;

    /// @notice default Instruction values
    uint256 public DEFAULT_SALT;
    uint256 public DEFAULT_MAX_EXECUTIONS;
    address public DEFAULT_ACTION;
    bytes public DEFAULT_ARGS;

    uint256 public sharedForkId;

    function setUpFork() public {
        try vm.activeFork() returns (uint256 forkId) {
            if (forkId != sharedForkId) {
                vm.selectFork(sharedForkId);
            }
        } catch {
            string memory rpcUrl = vm.envOr("SEPOLIA_RPC_URL", vm.rpcUrl("sepolia"));
            sharedForkId = vm.createSelectFork(rpcUrl);
        }
    }

    function setUp() public virtual {
        /// @notice delegate user to OtimDelegate
        vm.signAndAttachDelegation(address(delegate), userEOA.privateKey);

        /// @notice deal some Ether to user and target
        vm.deal(address(user), USER_START_BALANCE);
    }

    /// @notice build an Instruction and save it in state vars for use
    function buildInstruction(uint256 salt_, uint256 maxExecutions_, address action_, bytes memory args_) public {
        InstructionLib.Instruction memory _instruction =
            InstructionLib.Instruction(salt_, maxExecutions_, action_, args_);

        instruction = _instruction;

        instructionId = _id(_instruction);

        (bytes32 instructionTypeHash, bytes32 argumentsHash) = IAction(action_).argumentsHash(args_);

        instructionHash = _signingHash(_instruction, delegate.domainSeparator(), instructionTypeHash, argumentsHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userEOA.privateKey, instructionHash);
        instructionSig = InstructionLib.Signature(v, r, s);

        InstructionLib.InstructionDeactivation memory _deactivation =
            InstructionLib.InstructionDeactivation(instructionId);

        deactivation = _deactivation;

        deactivationHash = _signingHash(_deactivation, delegate.domainSeparator());
        (uint8 dv, bytes32 dr, bytes32 ds) = vm.sign(userEOA.privateKey, deactivationHash);
        deactivationSig = InstructionLib.Signature(dv, dr, ds);
    }

    /// @notice build default Instruction
    function buildInstruction() public {
        buildInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, DEFAULT_ARGS);
    }

    /// @notice build an Instruction and save it in state vars for use
    function returnInstruction(uint256 salt_, uint256 maxExecutions_, address action_, bytes memory args_)
        public
        pure
        returns (InstructionLib.Instruction memory _instruction)
    {
        _instruction = InstructionLib.Instruction(salt_, maxExecutions_, action_, args_);
    }

    /// @notice build default Instruction
    function returnInstruction() public view returns (InstructionLib.Instruction memory) {
        return returnInstruction(DEFAULT_SALT, DEFAULT_MAX_EXECUTIONS, DEFAULT_ACTION, DEFAULT_ARGS);
    }

    function _id(InstructionLib.Instruction memory _instruction) public pure returns (bytes32) {
        return keccak256(abi.encode(_instruction));
    }

    function _signingHash(
        InstructionLib.Instruction memory _instruction,
        bytes32 domainSeparator,
        bytes32 instructionTypeHash,
        bytes32 argumentsHash
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                Constants.EIP712_PREFIX,
                domainSeparator,
                keccak256(
                    abi.encode(
                        instructionTypeHash,
                        _instruction.salt,
                        _instruction.maxExecutions,
                        _instruction.action,
                        argumentsHash
                    )
                )
            )
        );
    }

    function _signingHash(InstructionLib.InstructionDeactivation memory _deactivation, bytes32 domainSeparator)
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                Constants.EIP712_PREFIX,
                domainSeparator,
                keccak256(abi.encode(InstructionLib.DEACTIVATION_TYPEHASH, _deactivation.instructionId))
            )
        );
    }
}
