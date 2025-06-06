/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import { Contract, ContractFactory, Overrides } from "@ethersproject/contracts";

import type { CurrencyLibrary } from "../CurrencyLibrary";

export class CurrencyLibrary__factory extends ContractFactory {
  constructor(signer?: Signer) {
    super(_abi, _bytecode, signer);
  }

  deploy(overrides?: Overrides): Promise<CurrencyLibrary> {
    return super.deploy(overrides || {}) as Promise<CurrencyLibrary>;
  }
  getDeployTransaction(overrides?: Overrides): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): CurrencyLibrary {
    return super.attach(address) as CurrencyLibrary;
  }
  connect(signer: Signer): CurrencyLibrary__factory {
    return super.connect(signer) as CurrencyLibrary__factory;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): CurrencyLibrary {
    return new Contract(address, _abi, signerOrProvider) as CurrencyLibrary;
  }
}

const _abi = [
  {
    inputs: [],
    name: "ERC20TransferFailed",
    type: "error",
  },
  {
    inputs: [],
    name: "NativeTransferFailed",
    type: "error",
  },
  {
    inputs: [],
    name: "ADDRESS_ZERO",
    outputs: [
      {
        internalType: "Currency",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

const _bytecode =
  "0x6080806040523460175760469081601c823930815050f35b5f80fdfe60808060405260043610156011575f80fd5b5f3560e01c6366e79509146023575f80fd5b5f366003190112603557805f60209252f35b5f80fdfea164736f6c634300081a000a";
