// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {IUniversalRouter} from "@uniswap-universal-router/contracts/interfaces/IUniversalRouter.sol";
import {IUniswapV3Factory} from "@uniswap-v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import {Commands} from "@uniswap-universal-router/contracts/libraries/Commands.sol";

import {InstructionLib} from "../libraries/Instruction.sol";
import {UniswapV3OracleParameters} from "./libraries/UniswapV3OracleParameters.sol";

import {OtimFee} from "./fee-models/OtimFee.sol";

import {IAction} from "./interfaces/IAction.sol";
import {ISweepUniswapV3Action, INSTRUCTION_TYPEHASH, ARGUMENTS_TYPEHASH} from "./interfaces/ISweepUniswapV3Action.sol";

import {
    InvalidArguments,
    InsufficientBalance,
    BalanceUnderThreshold,
    UniswapV3PoolDoesNotExist
} from "./errors/Errors.sol";

/// @title SweepUniswapV3Action
/// @author Otim Labs, Inc.
/// @notice an Action that sweeps tokens to Uniswap V3
contract SweepUniswapV3Action is IAction, ISweepUniswapV3Action, OtimFee {
    using SafeERC20 for IERC20;

    /// @notice the Uniswap UniversalRouter contract
    IUniversalRouter public immutable router;
    /// @notice the Uniswap V3 factory contract
    IUniswapV3Factory public immutable uniswapV3Factory;
    /// @notice the address of the WETH9 token contract
    address public immutable wethAddress;

    /// @notice the UniversalRouter commands to wrap ETH then swap WETH for a given ERC20
    bytes public constant ETH_TO_ERC20_COMMANDS =
        abi.encodePacked(uint8(Commands.WRAP_ETH), uint8(Commands.V3_SWAP_EXACT_IN));

    /// @notice the UniversalRouter commands to swap a given ERC20 to WETH then unwrap to ETH
    bytes public constant ERC20_TO_ETH_COMMANDS =
        abi.encodePacked(uint8(Commands.V3_SWAP_EXACT_IN), uint8(Commands.UNWRAP_WETH));

    /// @notice the UniversalRouter command to swap a given ERC20 for another ERC20
    bytes public constant ERC20_TO_ERC20_COMMAND = abi.encodePacked(uint8(Commands.V3_SWAP_EXACT_IN));

    constructor(
        address routerAddress,
        address factoryAddress,
        address wethAddress_,
        address feeTokenRegistryAddress,
        address treasuryAddress,
        uint256 gasConstant_
    ) OtimFee(feeTokenRegistryAddress, treasuryAddress, gasConstant_) {
        router = IUniversalRouter(routerAddress);
        uniswapV3Factory = IUniswapV3Factory(factoryAddress);
        // slither-disable-next-line missing-zero-check
        wethAddress = wethAddress_;
    }

    /// @inheritdoc IAction
    function argumentsHash(bytes calldata arguments) public pure returns (bytes32, bytes32) {
        return (INSTRUCTION_TYPEHASH, hash(abi.decode(arguments, (SweepUniswapV3))));
    }

    /// @inheritdoc ISweepUniswapV3Action
    function hash(SweepUniswapV3 memory arguments) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ARGUMENTS_TYPEHASH,
                arguments.recipient,
                arguments.tokenIn,
                arguments.tokenOut,
                arguments.feeTier,
                arguments.threshold,
                arguments.endBalance,
                arguments.floorAmountOut,
                arguments.meanPriceLookBack,
                arguments.maxPriceDeviationBPS,
                hash(arguments.fee)
            )
        );
    }

    /// @inheritdoc IAction
    function execute(
        InstructionLib.Instruction calldata instruction,
        InstructionLib.Signature calldata,
        InstructionLib.ExecutionState calldata executionState
    ) external override returns (bool) {
        // initial gas measurement for fee calculation
        uint256 startGas = gasleft();

        // decode the arguments from the instruction
        SweepUniswapV3 memory arguments = abi.decode(instruction.arguments, (SweepUniswapV3));

        // check if this is the first execution
        if (executionState.executionCount == 0) {
            // make sure arguments are well-formed
            if (
                arguments.tokenIn == arguments.tokenOut || arguments.recipient == address(0)
                    || arguments.endBalance > arguments.threshold || arguments.meanPriceLookBack == 0
                    || arguments.maxPriceDeviationBPS == 0
            ) {
                revert InvalidArguments();
            }
        }

        address internalTokenIn = arguments.tokenIn;
        address internalTokenOut = arguments.tokenOut;

        uint256 tokenInBalance;

        if (arguments.tokenIn == address(0)) {
            internalTokenIn = wethAddress;

            tokenInBalance = address(this).balance;
        } else {
            tokenInBalance = IERC20(arguments.tokenIn).balanceOf(address(this));

            if (arguments.tokenOut == address(0)) {
                internalTokenOut = wethAddress;
            }
        }

        // get the Uniswap V3 pool address for the given token pair and fee tier
        address poolAddress = uniswapV3Factory.getPool(internalTokenIn, internalTokenOut, arguments.feeTier);

        // if the pool does not exist, revert
        if (poolAddress == address(0)) {
            revert UniswapV3PoolDoesNotExist();
        }

        // slither-disable-next-line incorrect-equality
        if (tokenInBalance < arguments.threshold || tokenInBalance == arguments.endBalance) {
            revert BalanceUnderThreshold();
        }

        uint256 swapAmount = tokenInBalance - arguments.endBalance;

        // calculate the minimum amount out with TWAP deviation
        uint256 minAmountOutWithTwapDeviation = UniswapV3OracleParameters.getMinAmountOutWithTwapDeviation(
            poolAddress,
            internalTokenIn,
            internalTokenOut,
            arguments.feeTier,
            swapAmount,
            arguments.meanPriceLookBack,
            arguments.maxPriceDeviationBPS
        );

        // if the calculated minAmountOutWithTwapDeviation is less than the floorAmountOut, use the floorAmountOut
        uint256 minAmountOut = minAmountOutWithTwapDeviation < arguments.floorAmountOut
            ? arguments.floorAmountOut
            : minAmountOutWithTwapDeviation;

        // initialize variable to hold amount of ETH to send to the UniversalRouter
        // slither-disable-next-line uninitialized-local
        uint256 ethValue;

        // initialize variables to hold UniversalRouter commands and inputs
        bytes memory commands;
        bytes[] memory inputs;

        // check if input token is ETH
        if (arguments.tokenIn == address(0)) {
            // send amountIn ETH to the UniversalRouter
            ethValue = swapAmount;

            // encode commands and inputs to wrap the ETH then swap WETH for the ERC20,
            commands = ETH_TO_ERC20_COMMANDS;
            inputs = getEthToErc20Inputs(arguments, swapAmount, minAmountOut);
        } else {
            // transfer ERC20 tokens to the UniversalRouter
            IERC20(arguments.tokenIn).safeTransfer(address(router), swapAmount);

            // check if output token is ETH
            if (arguments.tokenOut == address(0)) {
                // encode commands and inputs to swap ERC20 for WETH then unwrap the WETH
                commands = ERC20_TO_ETH_COMMANDS;
                inputs = getErc20ToEthInputs(arguments, swapAmount, minAmountOut);
            } else {
                // encode command and inputs to swap ERC20 for another ERC20
                commands = ERC20_TO_ERC20_COMMAND;
                inputs = getErc20ToErc20Inputs(arguments, swapAmount, minAmountOut);
            }
        }

        // call the UniversalRouter with the encoded commands and inputs
        router.execute{value: ethValue}(commands, inputs, block.timestamp);

        // charge the fee
        chargeFee(startGas - gasleft(), arguments.fee);

        // this Action has no auto-deactivation paths
        return false;
    }

    /// @notice encodes the inputs for wrapping ETH then swapping WETH for an ERC20
    /// @param arguments - the SweepUniswapV3 struct
    /// @param minAmountOut - the minimum amount out to set for the swap
    /// @return inputs - the encoded UniversalRouter inputs
    function getEthToErc20Inputs(SweepUniswapV3 memory arguments, uint256 swapAmount, uint256 minAmountOut)
        internal
        view
        returns (bytes[] memory inputs)
    {
        inputs = new bytes[](2);
        // input for wrapping ETH
        // (address recipient,uint256 amount)
        inputs[0] = abi.encode(address(router), swapAmount);
        // input for swapping WETH for an ERC20
        // (address recipient,uint256 amountIn,uint256 amountOutMinimum,bytes path,bool payWithPermit2)
        inputs[1] = abi.encode(
            arguments.recipient,
            swapAmount,
            minAmountOut,
            abi.encodePacked(wethAddress, arguments.feeTier, arguments.tokenOut),
            false
        );
    }

    /// @notice encodes the inputs for swapping an ERC20 for WETH then unwrapping the WETH
    /// @param arguments - the SweepUniswapV3 struct
    /// @param minAmountOut - the minimum amount out to set for the swap
    /// @return inputs - the encoded UniversalRouter inputs
    function getErc20ToEthInputs(SweepUniswapV3 memory arguments, uint256 swapAmount, uint256 minAmountOut)
        internal
        view
        returns (bytes[] memory inputs)
    {
        inputs = new bytes[](2);
        // input for swapping an ERC20 for WETH
        // (address recipient,uint256 amountIn,uint256 amountOutMinimum,bytes path,bool payWithPermit2)
        inputs[0] = abi.encode(
            address(router),
            swapAmount,
            minAmountOut,
            abi.encodePacked(arguments.tokenIn, arguments.feeTier, wethAddress),
            false
        );
        // input for unwrapping WETH to ETH
        // (address recipient,uint256 amountMin)
        inputs[1] = abi.encode(arguments.recipient, minAmountOut);
    }

    /// @notice encodes the inputs for swapping an ERC20 for another ERC20
    /// @param arguments - the SweepUniswapV3 struct
    /// @param minAmountOut - the minimum amount out to set for the swap
    /// @return inputs - the encoded UniversalRouter inputs
    function getErc20ToErc20Inputs(SweepUniswapV3 memory arguments, uint256 swapAmount, uint256 minAmountOut)
        internal
        pure
        returns (bytes[] memory inputs)
    {
        inputs = new bytes[](1);
        // input for swapping an ERC20 for another ERC20
        // (address recipient,uint256 amountIn,uint256 amountOutMinimum,bytes path,bool payWithPermit2)
        inputs[0] = abi.encode(
            arguments.recipient,
            swapAmount,
            minAmountOut,
            abi.encodePacked(arguments.tokenIn, arguments.feeTier, arguments.tokenOut),
            false
        );
    }
}
