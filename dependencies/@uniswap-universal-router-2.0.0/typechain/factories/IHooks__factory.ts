/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer } from "ethers";
import { Provider } from "@ethersproject/providers";

import type { IHooks } from "../IHooks";

export class IHooks__factory {
  static connect(address: string, signerOrProvider: Signer | Provider): IHooks {
    return new Contract(address, _abi, signerOrProvider) as IHooks;
  }
}

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        components: [
          {
            internalType: "Currency",
            name: "currency0",
            type: "address",
          },
          {
            internalType: "Currency",
            name: "currency1",
            type: "address",
          },
          {
            internalType: "uint24",
            name: "fee",
            type: "uint24",
          },
          {
            internalType: "int24",
            name: "tickSpacing",
            type: "int24",
          },
          {
            internalType: "contract IHooks",
            name: "hooks",
            type: "address",
          },
        ],
        internalType: "struct PoolKey",
        name: "key",
        type: "tuple",
      },
      {
        components: [
          {
            internalType: "int24",
            name: "tickLower",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "tickUpper",
            type: "int24",
          },
          {
            internalType: "int256",
            name: "liquidityDelta",
            type: "int256",
          },
          {
            internalType: "bytes32",
            name: "salt",
            type: "bytes32",
          },
        ],
        internalType: "struct IPoolManager.ModifyLiquidityParams",
        name: "params",
        type: "tuple",
      },
      {
        internalType: "BalanceDelta",
        name: "delta",
        type: "int256",
      },
      {
        internalType: "BalanceDelta",
        name: "feesAccrued",
        type: "int256",
      },
      {
        internalType: "bytes",
        name: "hookData",
        type: "bytes",
      },
    ],
    name: "afterAddLiquidity",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
      {
        internalType: "BalanceDelta",
        name: "",
        type: "int256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        components: [
          {
            internalType: "Currency",
            name: "currency0",
            type: "address",
          },
          {
            internalType: "Currency",
            name: "currency1",
            type: "address",
          },
          {
            internalType: "uint24",
            name: "fee",
            type: "uint24",
          },
          {
            internalType: "int24",
            name: "tickSpacing",
            type: "int24",
          },
          {
            internalType: "contract IHooks",
            name: "hooks",
            type: "address",
          },
        ],
        internalType: "struct PoolKey",
        name: "key",
        type: "tuple",
      },
      {
        internalType: "uint256",
        name: "amount0",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "amount1",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "hookData",
        type: "bytes",
      },
    ],
    name: "afterDonate",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        components: [
          {
            internalType: "Currency",
            name: "currency0",
            type: "address",
          },
          {
            internalType: "Currency",
            name: "currency1",
            type: "address",
          },
          {
            internalType: "uint24",
            name: "fee",
            type: "uint24",
          },
          {
            internalType: "int24",
            name: "tickSpacing",
            type: "int24",
          },
          {
            internalType: "contract IHooks",
            name: "hooks",
            type: "address",
          },
        ],
        internalType: "struct PoolKey",
        name: "key",
        type: "tuple",
      },
      {
        internalType: "uint160",
        name: "sqrtPriceX96",
        type: "uint160",
      },
      {
        internalType: "int24",
        name: "tick",
        type: "int24",
      },
    ],
    name: "afterInitialize",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        components: [
          {
            internalType: "Currency",
            name: "currency0",
            type: "address",
          },
          {
            internalType: "Currency",
            name: "currency1",
            type: "address",
          },
          {
            internalType: "uint24",
            name: "fee",
            type: "uint24",
          },
          {
            internalType: "int24",
            name: "tickSpacing",
            type: "int24",
          },
          {
            internalType: "contract IHooks",
            name: "hooks",
            type: "address",
          },
        ],
        internalType: "struct PoolKey",
        name: "key",
        type: "tuple",
      },
      {
        components: [
          {
            internalType: "int24",
            name: "tickLower",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "tickUpper",
            type: "int24",
          },
          {
            internalType: "int256",
            name: "liquidityDelta",
            type: "int256",
          },
          {
            internalType: "bytes32",
            name: "salt",
            type: "bytes32",
          },
        ],
        internalType: "struct IPoolManager.ModifyLiquidityParams",
        name: "params",
        type: "tuple",
      },
      {
        internalType: "BalanceDelta",
        name: "delta",
        type: "int256",
      },
      {
        internalType: "BalanceDelta",
        name: "feesAccrued",
        type: "int256",
      },
      {
        internalType: "bytes",
        name: "hookData",
        type: "bytes",
      },
    ],
    name: "afterRemoveLiquidity",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
      {
        internalType: "BalanceDelta",
        name: "",
        type: "int256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        components: [
          {
            internalType: "Currency",
            name: "currency0",
            type: "address",
          },
          {
            internalType: "Currency",
            name: "currency1",
            type: "address",
          },
          {
            internalType: "uint24",
            name: "fee",
            type: "uint24",
          },
          {
            internalType: "int24",
            name: "tickSpacing",
            type: "int24",
          },
          {
            internalType: "contract IHooks",
            name: "hooks",
            type: "address",
          },
        ],
        internalType: "struct PoolKey",
        name: "key",
        type: "tuple",
      },
      {
        components: [
          {
            internalType: "bool",
            name: "zeroForOne",
            type: "bool",
          },
          {
            internalType: "int256",
            name: "amountSpecified",
            type: "int256",
          },
          {
            internalType: "uint160",
            name: "sqrtPriceLimitX96",
            type: "uint160",
          },
        ],
        internalType: "struct IPoolManager.SwapParams",
        name: "params",
        type: "tuple",
      },
      {
        internalType: "BalanceDelta",
        name: "delta",
        type: "int256",
      },
      {
        internalType: "bytes",
        name: "hookData",
        type: "bytes",
      },
    ],
    name: "afterSwap",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
      {
        internalType: "int128",
        name: "",
        type: "int128",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        components: [
          {
            internalType: "Currency",
            name: "currency0",
            type: "address",
          },
          {
            internalType: "Currency",
            name: "currency1",
            type: "address",
          },
          {
            internalType: "uint24",
            name: "fee",
            type: "uint24",
          },
          {
            internalType: "int24",
            name: "tickSpacing",
            type: "int24",
          },
          {
            internalType: "contract IHooks",
            name: "hooks",
            type: "address",
          },
        ],
        internalType: "struct PoolKey",
        name: "key",
        type: "tuple",
      },
      {
        components: [
          {
            internalType: "int24",
            name: "tickLower",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "tickUpper",
            type: "int24",
          },
          {
            internalType: "int256",
            name: "liquidityDelta",
            type: "int256",
          },
          {
            internalType: "bytes32",
            name: "salt",
            type: "bytes32",
          },
        ],
        internalType: "struct IPoolManager.ModifyLiquidityParams",
        name: "params",
        type: "tuple",
      },
      {
        internalType: "bytes",
        name: "hookData",
        type: "bytes",
      },
    ],
    name: "beforeAddLiquidity",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        components: [
          {
            internalType: "Currency",
            name: "currency0",
            type: "address",
          },
          {
            internalType: "Currency",
            name: "currency1",
            type: "address",
          },
          {
            internalType: "uint24",
            name: "fee",
            type: "uint24",
          },
          {
            internalType: "int24",
            name: "tickSpacing",
            type: "int24",
          },
          {
            internalType: "contract IHooks",
            name: "hooks",
            type: "address",
          },
        ],
        internalType: "struct PoolKey",
        name: "key",
        type: "tuple",
      },
      {
        internalType: "uint256",
        name: "amount0",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "amount1",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "hookData",
        type: "bytes",
      },
    ],
    name: "beforeDonate",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        components: [
          {
            internalType: "Currency",
            name: "currency0",
            type: "address",
          },
          {
            internalType: "Currency",
            name: "currency1",
            type: "address",
          },
          {
            internalType: "uint24",
            name: "fee",
            type: "uint24",
          },
          {
            internalType: "int24",
            name: "tickSpacing",
            type: "int24",
          },
          {
            internalType: "contract IHooks",
            name: "hooks",
            type: "address",
          },
        ],
        internalType: "struct PoolKey",
        name: "key",
        type: "tuple",
      },
      {
        internalType: "uint160",
        name: "sqrtPriceX96",
        type: "uint160",
      },
    ],
    name: "beforeInitialize",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        components: [
          {
            internalType: "Currency",
            name: "currency0",
            type: "address",
          },
          {
            internalType: "Currency",
            name: "currency1",
            type: "address",
          },
          {
            internalType: "uint24",
            name: "fee",
            type: "uint24",
          },
          {
            internalType: "int24",
            name: "tickSpacing",
            type: "int24",
          },
          {
            internalType: "contract IHooks",
            name: "hooks",
            type: "address",
          },
        ],
        internalType: "struct PoolKey",
        name: "key",
        type: "tuple",
      },
      {
        components: [
          {
            internalType: "int24",
            name: "tickLower",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "tickUpper",
            type: "int24",
          },
          {
            internalType: "int256",
            name: "liquidityDelta",
            type: "int256",
          },
          {
            internalType: "bytes32",
            name: "salt",
            type: "bytes32",
          },
        ],
        internalType: "struct IPoolManager.ModifyLiquidityParams",
        name: "params",
        type: "tuple",
      },
      {
        internalType: "bytes",
        name: "hookData",
        type: "bytes",
      },
    ],
    name: "beforeRemoveLiquidity",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        components: [
          {
            internalType: "Currency",
            name: "currency0",
            type: "address",
          },
          {
            internalType: "Currency",
            name: "currency1",
            type: "address",
          },
          {
            internalType: "uint24",
            name: "fee",
            type: "uint24",
          },
          {
            internalType: "int24",
            name: "tickSpacing",
            type: "int24",
          },
          {
            internalType: "contract IHooks",
            name: "hooks",
            type: "address",
          },
        ],
        internalType: "struct PoolKey",
        name: "key",
        type: "tuple",
      },
      {
        components: [
          {
            internalType: "bool",
            name: "zeroForOne",
            type: "bool",
          },
          {
            internalType: "int256",
            name: "amountSpecified",
            type: "int256",
          },
          {
            internalType: "uint160",
            name: "sqrtPriceLimitX96",
            type: "uint160",
          },
        ],
        internalType: "struct IPoolManager.SwapParams",
        name: "params",
        type: "tuple",
      },
      {
        internalType: "bytes",
        name: "hookData",
        type: "bytes",
      },
    ],
    name: "beforeSwap",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
      {
        internalType: "BeforeSwapDelta",
        name: "",
        type: "int256",
      },
      {
        internalType: "uint24",
        name: "",
        type: "uint24",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
];
