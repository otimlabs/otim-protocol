// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

/// @notice Interface for Circle's CCTP V2 TokenMessenger contract
/// @dev Note: Unlike CCTP V1, the V2 depositForBurn function does not return a nonce.
///      The nonce can be retrieved from the Circle API or from transaction events if needed.
interface ITokenMessengerV2 {
    /// @notice Burns tokens on the source chain to be minted on the destination chain
    /// @param amount Amount of tokens to burn
    /// @param destinationDomain CCTP domain ID of the destination chain
    /// @param mintRecipient Recipient address on the destination chain (as bytes32)
    /// @param burnToken Address of the token to burn
    /// @param destinationCaller Address that can call receiveMessage on destination (0x0 for anyone)
    /// @param maxFee Maximum fee for Fast Transfer in units of burn token
    /// @param minFinalityThreshold Minimum finality level (1000 for Fast, 2000 for Standard)
    /// @dev This function does NOT return a nonce (unlike CCTP V1)
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external;

    /// @notice Burns tokens with hook data for custom destination logic
    /// @param amount Amount of tokens to burn
    /// @param destinationDomain CCTP domain ID of the destination chain
    /// @param mintRecipient Recipient address on the destination chain (as bytes32)
    /// @param burnToken Address of the token to burn
    /// @param destinationCaller Address that can call receiveMessage on destination (0x0 for anyone)
    /// @param maxFee Maximum fee for Fast Transfer in units of burn token
    /// @param minFinalityThreshold Minimum finality level (1000 for Fast, 2000 for Standard)
    /// @param hookData Custom data to be passed to hook contract on destination
    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bytes calldata hookData
    ) external;
}

