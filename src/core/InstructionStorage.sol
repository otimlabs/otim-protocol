// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

import {Constants} from "../libraries/Constants.sol";
import {InstructionLib} from "../libraries/Instruction.sol";

import {IInstructionStorage} from "./interfaces/IInstructionStorage.sol";

/// @title InstructionStorage
/// @author Otim Labs, Inc.
/// @notice external storage contract for storing Instruction execution state
contract InstructionStorage is IInstructionStorage {
    //slither-disable-start too-many-digits

    /// @notice hash of the "delegation designator" i.e. keccak256(0xef0100 || delegate_address)
    bytes32 public immutable designatorHash;

    /// @notice reverts if the modified function is not called from within the code of a delegated EOA
    /// @dev if the EOA codehash matches `designator`, the EOA is delegated to some contract,
    ///      and if msg.sender is not equal to tx.origin, the EOA has not called the function directly
    modifier fromDelegateCodeOnly() {
        // IInstructionStorage.DataCorruptionAttempted.selector = 0xabdc7b7a

        bytes32 designatorHash_ = designatorHash;

        assembly {
            // revert if msg.sender == tx.origin OR msg.sender.codehash != delegateCodehash
            // from innermost to outermost:
            // 1. retrieve the codehash of the msg.sender
            // 2. load `delegateCodehash` from storage (slot 0 is the address of the `owner` and slot 1 is the `delegateCodehash`)
            // 3. compare the codehash of msg.sender to the `delegateCodehash`
            // 4. if they are not equal, revert
            // 5. compare msg.sender to tx.origin
            // 6. if they are equal, revert
            if or(eq(caller(), origin()), iszero(eq(extcodehash(caller()), designatorHash_))) {
                // store `IInstructionStorage.DataCorruptionAttempted.selector` in memory.
                // memory bytes [0, 27] are zero and bytes [28, 31] are the 4-byte-long selector
                mstore(0x0, 0xabdc7b7a)
                // decoding this revert statement: we revert starting at memory byte 28 with a length of 4
                // to return the selector as the reason for the revert
                revert(0x1c, 0x4)
            }
        }
        _;
    }

    constructor() {
        // construct the "delegation designator", then hash it.
        // OtimDelegate will deploy this contract so msg.sender will be the address of the delegate contract
        designatorHash = keccak256(abi.encodePacked(Constants.EIP7702_PREFIX, msg.sender));
    }

    /// @inheritdoc IInstructionStorage
    function incrementExecutionCounter(bytes32 instructionId) external fromDelegateCodeOnly {
        assembly {
            // store msg.sender in memory: bytes [0, 11] are 0, bytes [12, 31] are msg.sender address
            mstore(0x0, caller())
            // store `instructionId` in memory bytes [32, 63]
            mstore(0x20, instructionId)
            // compute the keccak256 hash of memory bytes [0, 63] to use as the storage `key`
            let key := keccak256(0x0, 0x40)
            // from innermost to outermost:
            // 1. load the storage value at `key`. This value is structured as follows:
            //    byte 0 is free,
            //    byte 1 is the `deactivated` boolean,
            //    bytes [2, 16] are the `counter`,
            //    bytes [17, 31] are the `lastExecuted` timestamp
            // 2. discard `lastExecuted` by masking out the last 15 bytes
            // 3. increment `counter` by 1 (add 1 left-shifted by 15 bytes to the retrieved storage value)
            // 4. set the last 15 bytes of the storage value to the current block.timestamp
            // 5. store the updated storage value at `key`
            /// @dev casting `block.timestamp` from uint256 to uint120 is safe because it will only overflow
            ///      2^120 seconds after epoch which is approximately 40 Octillion years from now... we'll have a v2 by then :)
            ///      Similarly, using a uint120 for the `counter` is safe because it will only overflow after
            ///      2^120 executions (approximately 1 Undecillion executions). Also, despite this being completely infeasible,
            ///      if `counter` were to overflow, it would simply set the `deactivated` boolean to true, making it
            ///      impossible to execute the Instruction again.
            sstore(
                key,
                or(
                    add(
                        and(sload(key), 0xffffffffffffffffffffffffffffffffff000000000000000000000000000000),
                        0x1000000000000000000000000000000
                    ),
                    timestamp()
                )
            )
        }
    }

    /// @inheritdoc IInstructionStorage
    function incrementAndDeactivate(bytes32 instructionId) external fromDelegateCodeOnly {
        assembly {
            // store msg.sender in memory: bytes [0, 11] are 0, bytes [12, 31] are msg.sender address
            mstore(0x0, caller())
            // store `instructionId` in memory bytes [32, 63]
            mstore(0x20, instructionId)
            // compute the keccak256 hash of memory bytes [0, 63] to use as the storage `key`
            let key := keccak256(0x0, 0x40)
            // from innermost to outermost:
            // 1. load the storage value at `key`. This value is structured as follows:
            //    byte 0 is free,
            //    byte 1 is the `deactivated` boolean,
            //    bytes [2, 16] are the `counter`,
            //    bytes [17, 31] are the `lastExecuted` timestamp
            // 2. discard `lastExecuted` by masking out the last 15 bytes
            // 3. increment `counter` by 1 (add 1 left-shifted by 15 bytes to the retrieved storage value)
            // 4. set the last 15 bytes of the storage value to the current block.timestamp
            // 5. set the `deactivated` boolean to true
            // 6. store the updated storage value at `key`
            sstore(
                key,
                or(
                    or(
                        add(
                            and(sload(key), 0xffffffffffffffffffffffffffffffffff000000000000000000000000000000),
                            0x1000000000000000000000000000000
                        ),
                        timestamp()
                    ),
                    0x1000000000000000000000000000000000000000000000000000000000000
                )
            )
        }
    }

    /// @inheritdoc IInstructionStorage
    function deactivateStorage(bytes32 instructionId) external fromDelegateCodeOnly {
        assembly {
            // store msg.sender in memory: bytes [0, 11] are 0, bytes [12, 31] are msg.sender address
            mstore(0x0, caller())
            // store `instructionId` in memory bytes [32, 63]
            mstore(0x20, instructionId)
            // compute the keccak256 hash of memory bytes [0, 63] to use as the storage `key`
            let key := keccak256(0x0, 0x40)
            // 1. load the storage value at `key`
            // 2. set the `deactivated` boolean to true
            // 3. store the updated storage value at `key`
            sstore(key, or(sload(key), 0x1000000000000000000000000000000000000000000000000000000000000))
        }
    }

    /// @inheritdoc IInstructionStorage
    function isDeactivated(bytes32 instructionId) external view returns (bool) {
        assembly {
            // store msg.sender in memory: bytes [0, 11] are 0, bytes [12, 31] are msg.sender address
            mstore(0x0, caller())
            // store `instructionId` in memory bytes [32, 63]
            mstore(0x20, instructionId)
            // compute the keccak256 hash of memory bytes [0, 63] to use as the storage `key`
            let key := keccak256(0x0, 0x40)
            // 1. load the storage value at `key`
            // 2. right-shift the loaded storage value by 30 bytes to get the `deactivated` boolean
            // 3. store the `deactivated` boolean in memory bytes [0, 31]
            mstore(0x0, shr(0xf0, sload(key)))
            // return the `deactivated` boolean (memory starting at 0 with a length of 32)
            return(0x0, 0x20)
        }
    }

    /// @inheritdoc IInstructionStorage
    function getExecutionState(bytes32 instructionId) external view returns (InstructionLib.ExecutionState memory) {
        assembly {
            // store msg.sender in memory: bytes [0, 11] are 0, bytes [12, 31] are msg.sender address
            mstore(0x0, caller())
            // store `instructionId` in memory bytes [32, 63]
            mstore(0x20, instructionId)
            // compute the keccak256 hash of memory bytes [0, 63] to use as the storage `key`
            let key := keccak256(0x0, 0x40)
            // load the storage value at `key` into `value`
            let value := sload(key)
            // load the 32-byte word at memory location 0x40 into `ptr`. This is the location of the next free slot in memory
            /// @dev we have to use free memory slots to store return values here because they are more than 64 bytes
            let ptr := mload(0x40)
            // 1. right-shift `value` by 30 bytes to get the `deactivated` boolean
            // 2. store this at memory location `ptr`
            mstore(ptr, shr(0xf0, value))
            // 1. right-shift `value` by 15 bytes to get rid of `lastExecuted`
            // 2. mask out the first 17 bytes of `value` to get `counter`
            // 3. store this at memory location `ptr` + 32 bytes
            mstore(add(ptr, 0x20), and(0xffffffffffffffffffffffffffffff, shr(0x78, value)))
            // 1. mask out the first 17 bytes of `value` to get `lastExecuted`
            // 2. store this at memory location `ptr` + 64 bytes
            mstore(add(ptr, 0x40), and(0xffffffffffffffffffffffffffffff, value))
            // return `deactivated`, `counter`, and `lastExecuted` as separate values
            // by returning memory starting at `ptr` with a length of 96 bytes
            return(ptr, 0x60)
        }
    }

    /// @notice returns the execution state of an Instruction for a particular user
    /// @param instructionId - unique identifier for an Instruction
    /// @param user - address of the EOA to return execution state for
    /// @return executionState - the current execution state of the Instruction
    function getExecutionState(address user, bytes32 instructionId)
        external
        view
        returns (InstructionLib.ExecutionState memory)
    {
        assembly {
            // store `user` in memory: bytes [0, 11] are 0, bytes [12, 31] are `user`
            mstore(0x0, user)
            // store `instructionId` in memory bytes [32, 63]
            mstore(0x20, instructionId)
            // compute the keccak256 hash of memory bytes [0, 63] to use as the storage `key`
            let key := keccak256(0x0, 0x40)
            // load the storage value at `key` into `value`
            let value := sload(key)
            // load the 32-byte word at memory location 0x40 into `ptr`. This is the location of the next free slot in memory
            let ptr := mload(0x40)
            // 1. right-shift `value` by 30 bytes to get the `deactivated` boolean
            // 2. store this at memory location `ptr`
            mstore(ptr, shr(0xf0, value))
            // 1. right-shift `value` by 15 bytes to get rid of `lastExecuted`
            // 2. mask out the first 17 bytes of `value` to get `counter`
            // 3. store this at memory location `ptr` + 32 bytes
            mstore(add(ptr, 0x20), and(0xffffffffffffffffffffffffffffff, shr(0x78, value)))
            // 1. mask out the first 17 bytes of `value` to get `lastExecuted`
            // 2. store this at memory location `ptr` + 64 bytes
            mstore(add(ptr, 0x40), and(0xffffffffffffffffffffffffffffff, value))
            // return `deactivated`, `counter`, and `lastExecuted` as separate values
            // by returning memory starting at `ptr` with a length of 96 bytes
            return(ptr, 0x60)
        }
    }
    //slither-disable-end too-many-digits
}
