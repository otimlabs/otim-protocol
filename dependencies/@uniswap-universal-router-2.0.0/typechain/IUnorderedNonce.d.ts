/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import {
  ethers,
  EventFilter,
  Signer,
  BigNumber,
  BigNumberish,
  PopulatedTransaction,
} from "ethers";
import {
  Contract,
  ContractTransaction,
  PayableOverrides,
  CallOverrides,
} from "@ethersproject/contracts";
import { BytesLike } from "@ethersproject/bytes";
import { Listener, Provider } from "@ethersproject/providers";
import { FunctionFragment, EventFragment, Result } from "@ethersproject/abi";

interface IUnorderedNonceInterface extends ethers.utils.Interface {
  functions: {
    "nonces(address,uint256)": FunctionFragment;
    "revokeNonce(uint256)": FunctionFragment;
  };

  encodeFunctionData(
    functionFragment: "nonces",
    values: [string, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "revokeNonce",
    values: [BigNumberish]
  ): string;

  decodeFunctionResult(functionFragment: "nonces", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "revokeNonce",
    data: BytesLike
  ): Result;

  events: {};
}

export class IUnorderedNonce extends Contract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  on(event: EventFilter | string, listener: Listener): this;
  once(event: EventFilter | string, listener: Listener): this;
  addListener(eventName: EventFilter | string, listener: Listener): this;
  removeAllListeners(eventName: EventFilter | string): this;
  removeListener(eventName: any, listener: Listener): this;

  interface: IUnorderedNonceInterface;

  functions: {
    nonces(
      owner: string,
      word: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      0: BigNumber;
    }>;

    "nonces(address,uint256)"(
      owner: string,
      word: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      0: BigNumber;
    }>;

    revokeNonce(
      nonce: BigNumberish,
      overrides?: PayableOverrides
    ): Promise<ContractTransaction>;

    "revokeNonce(uint256)"(
      nonce: BigNumberish,
      overrides?: PayableOverrides
    ): Promise<ContractTransaction>;
  };

  nonces(
    owner: string,
    word: BigNumberish,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  "nonces(address,uint256)"(
    owner: string,
    word: BigNumberish,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  revokeNonce(
    nonce: BigNumberish,
    overrides?: PayableOverrides
  ): Promise<ContractTransaction>;

  "revokeNonce(uint256)"(
    nonce: BigNumberish,
    overrides?: PayableOverrides
  ): Promise<ContractTransaction>;

  callStatic: {
    nonces(
      owner: string,
      word: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "nonces(address,uint256)"(
      owner: string,
      word: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    revokeNonce(nonce: BigNumberish, overrides?: CallOverrides): Promise<void>;

    "revokeNonce(uint256)"(
      nonce: BigNumberish,
      overrides?: CallOverrides
    ): Promise<void>;
  };

  filters: {};

  estimateGas: {
    nonces(
      owner: string,
      word: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "nonces(address,uint256)"(
      owner: string,
      word: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    revokeNonce(
      nonce: BigNumberish,
      overrides?: PayableOverrides
    ): Promise<BigNumber>;

    "revokeNonce(uint256)"(
      nonce: BigNumberish,
      overrides?: PayableOverrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    nonces(
      owner: string,
      word: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "nonces(address,uint256)"(
      owner: string,
      word: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    revokeNonce(
      nonce: BigNumberish,
      overrides?: PayableOverrides
    ): Promise<PopulatedTransaction>;

    "revokeNonce(uint256)"(
      nonce: BigNumberish,
      overrides?: PayableOverrides
    ): Promise<PopulatedTransaction>;
  };
}
