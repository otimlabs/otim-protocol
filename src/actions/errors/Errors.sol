// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.26;

error InvalidArguments();

error InsufficientBalance();

error BalanceOverThreshold();
error BalanceUnderThreshold();

error UniswapV3PoolDoesNotExist();

error InstructionAlreadyDeactivated();

error CallOnceFailed(address target, bytes4 selector, bytes result);

error CCTPTokenNotSupported();
error CCTPMaxFeeTooLow(uint32 userMaxFeeThouBPS, uint256 cctpMinFee);

error MaxDepositTooLow();
error MaxWithdrawTooLow();
error TotalSharesTooLow();
