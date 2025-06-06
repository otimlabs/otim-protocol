/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer } from "ethers";
import { Provider } from "@ethersproject/providers";

import type { IUnorderedNonce } from "../IUnorderedNonce";

export class IUnorderedNonce__factory {
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): IUnorderedNonce {
    return new Contract(address, _abi, signerOrProvider) as IUnorderedNonce;
  }
}

const _abi = [
  {
    inputs: [],
    name: "NonceAlreadyUsed",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "word",
        type: "uint256",
      },
    ],
    name: "nonces",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "nonce",
        type: "uint256",
      },
    ],
    name: "revokeNonce",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
];
