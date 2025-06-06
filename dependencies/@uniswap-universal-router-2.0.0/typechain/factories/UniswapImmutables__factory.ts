/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer, BytesLike } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import { Contract, ContractFactory, Overrides } from "@ethersproject/contracts";

import type { UniswapImmutables } from "../UniswapImmutables";

export class UniswapImmutables__factory extends ContractFactory {
  constructor(signer?: Signer) {
    super(_abi, _bytecode, signer);
  }

  deploy(
    params: {
      v2Factory: string;
      v3Factory: string;
      pairInitCodeHash: BytesLike;
      poolInitCodeHash: BytesLike;
    },
    overrides?: Overrides
  ): Promise<UniswapImmutables> {
    return super.deploy(params, overrides || {}) as Promise<UniswapImmutables>;
  }
  getDeployTransaction(
    params: {
      v2Factory: string;
      v3Factory: string;
      pairInitCodeHash: BytesLike;
      poolInitCodeHash: BytesLike;
    },
    overrides?: Overrides
  ): TransactionRequest {
    return super.getDeployTransaction(params, overrides || {});
  }
  attach(address: string): UniswapImmutables {
    return super.attach(address) as UniswapImmutables;
  }
  connect(signer: Signer): UniswapImmutables__factory {
    return super.connect(signer) as UniswapImmutables__factory;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): UniswapImmutables {
    return new Contract(address, _abi, signerOrProvider) as UniswapImmutables;
  }
}

const _abi = [
  {
    inputs: [
      {
        components: [
          {
            internalType: "address",
            name: "v2Factory",
            type: "address",
          },
          {
            internalType: "address",
            name: "v3Factory",
            type: "address",
          },
          {
            internalType: "bytes32",
            name: "pairInitCodeHash",
            type: "bytes32",
          },
          {
            internalType: "bytes32",
            name: "poolInitCodeHash",
            type: "bytes32",
          },
        ],
        internalType: "struct UniswapParameters",
        name: "params",
        type: "tuple",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
];

const _bytecode =
  "0x610100604052346100f157604051601f61011a38819003918201601f19168301916001600160401b038311848410176100dd578084926080946040528339810103126100f15760405190608082016001600160401b038111838210176100dd5760405261006b816100f5565b9081835261007b602082016100f5565b60208401908152604082810151818601908152606093840151939095019283526001600160a01b03938416608052935160a0525190911660c0525160e052516010908161010a823960805181505060a05181505060c05181505060e051815050f35b634e487b7160e01b5f52604160045260245ffd5b5f80fd5b51906001600160a01b03821682036100f15756fe5f80fdfea164736f6c634300081a000a";
