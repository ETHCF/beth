---
title: BETH - Proof-of-Burn ERC-20
description: An ERC-20 token representing ETH that has been permanently removed from circulation via onchain burn
author: Zak Cole (@zscole)
discussions-to: <URL>
status: Draft
type: Standards Track
category: ERC
created: 2025-08-07
---

## Abstract
BETH is an ERC-20 token representing ETH that has been permanently removed from circulation via onchain burn. ETH sent to the BETH contract is forwarded to the Ethereum burn address and an equal amount of BETH is minted to the sender or a designated recipient. BETH is immutable, permissionless, and non-redeemable.

## Motivation
Wrapped Ether (WETH) became a foundational ERC-20 primitive by providing a standard, composable interface for ETH. BETH extends this pattern to ETH burning, creating a standard way to represent provably destroyed ETH. Protocols can now integrate burn mechanics without building custom verification systems.

## Specification

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119 and RFC 8174.

### Contract Properties
- **Symbol**: `BETH`
- **Name**: `BETH`
- **Decimals**: `18`
- **Mint Ratio**: `1 BETH : 1 ETH`
- **Burn Address**: `0x0000000000000000000000000000000000000000`
- **Upgradeability**: None
- **Access Control**: None (no ownership or privileged roles)
- **Redemption**: None (irreversible)

### External Functions

#### Core Functions
- `deposit() external payable`  
  Forwards `msg.value` ETH to the burn address, then mints equivalent BETH to `msg.sender`. Reverts if `msg.value` is zero or if forwarding fails.

- `depositTo(address recipient) external payable`  
  Forwards `msg.value` ETH to the burn address, then mints equivalent BETH to `recipient`. Reverts if `msg.value` is zero or if forwarding fails.

- `receive() external payable`  
  Handles direct ETH transfers. Equivalent to calling `deposit()`.

- `totalBurned() external view returns (uint256)`  
  Returns the cumulative amount of ETH permanently destroyed through this contract.

#### Standard ERC-20 Functions
BETH implements the complete ERC-20 interface: `totalSupply()`, `balanceOf()`, `transfer()`, `approve()`, `transferFrom()`, and `allowance()`.

### Optional Maintenance Function
- `flush() external`  
  Permissionless function that forwards any ETH balance held by the contract (e.g., due to forced ETH via `SELFDESTRUCT`) to the burn address. This function does not mint BETH. It increases `totalBurned` by the forwarded amount and emits `Burned(address(this), amount)`.

### Events
- `Burned(address indexed from, uint256 amount)` - Emitted when ETH is forwarded to the burn address
- `Minted(address indexed to, uint256 amount)` - Emitted when BETH tokens are minted
- Standard ERC-20 `Transfer` and `Approval` events per the ERC-20 specification

### Errors
- `ZeroDeposit()` - Thrown when attempting to deposit zero ETH
- `ForwardFailed()` - Thrown when the ETH transfer to the burn address fails

## Rationale
BETH mirrors WETH's design philosophy but for a permanent action—burning ETH. This approach provides:
- Simple, predictable integration for protocols
- Transparent burn tracking without custom verification
- No custody risk since ETH is immediately destroyed
- Immutable design with no governance or upgrade paths

## Backwards Compatibility
BETH is a standard ERC-20 token. Existing wallets, DEXs, and protocols work with BETH without any changes.

## Test Cases
Test cases are provided in the reference implementation repository under the `test/` directory, including:
- Unit tests for deposit and depositTo functions
- Fuzz testing for edge cases and invariants
- Gas optimization tests
- Reentrancy protection tests
- Force ETH handling via flush() function

## Security Considerations
- ETH is forwarded to a hardcoded burn address to eliminate custody risk.
- Contract holds no ETH; reentrancy is not possible in mint logic.
- Minting is only possible via payable deposit functions.
- ETH can be force-sent to the contract via `SELFDESTRUCT` from other contracts. The optional `flush()` function handles this edge case by forwarding such ETH to the burn address without minting BETH.

## Reference Implementation
The canonical implementation is provided below and in `src/BETH.sol`. It uses OpenZeppelin’s `ERC20` base, hardcodes the Ethereum burn address, and strictly follows this standard.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title BETH - Burned ETH
/// @notice Immutable ERC-20 token representing provably burnt ETH.
/// Sending ETH mints 1:1 BETH and forwards ETH to the burn address.
contract BETH is ERC20 {
    /// @dev Ethereum burn address
    address public constant ETH_BURN_ADDRESS = 0x0000000000000000000000000000000000000000;

    /// @dev Revert when a deposit with zero value is attempted
    error ZeroDeposit();
    /// @dev Revert when forwarding ETH to the burn address fails
    error ForwardFailed();

    /// @notice Emitted when ETH is forwarded to the burn address
    event Burned(address indexed from, uint256 amount);
    /// @notice Emitted when BETH is minted
    event Minted(address indexed to, uint256 amount);

    uint256 private _totalBurned;

    constructor() ERC20("BETH", "BETH") {}

    /// @inheritdoc ERC20
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /// @notice Total ETH permanently destroyed through this contract
    function totalBurned() external view returns (uint256) {
        return _totalBurned;
    }

    /// @notice Deposit ETH and mint BETH to the sender 1:1
    function deposit() external payable {
        _depositTo(msg.sender);
    }

    /// @notice Deposit ETH and mint BETH to a specified recipient 1:1
    /// @param recipient The address to receive minted BETH
    function depositTo(address recipient) external payable {
        _depositTo(recipient);
    }

    /// @notice Accept direct ETH transfers and mint BETH to the sender
    receive() external payable {
        _depositTo(msg.sender);
    }

    /// @notice Permissionless function to forward any stray ETH balance to the burn address
    /// This handles ETH that may have been force-sent to the contract (e.g., via selfdestruct).
    /// No BETH is minted for this operation.
    function flush() external {
        uint256 amount = address(this).balance;
        if (amount == 0) return;
        // Effects first to satisfy static analyzers; revert will roll back on failure below
        _totalBurned += amount;
        emit Burned(address(this), amount);
        (bool success, ) = payable(ETH_BURN_ADDRESS).call{value: amount}("");
        if (!success) revert ForwardFailed();
    }

    function _depositTo(address recipient) private returns (uint256 mintedAmount) {
        uint256 amount = msg.value;
        if (amount == 0) revert ZeroDeposit();

        // Forward ETH to the burn address
        (bool success, ) = payable(ETH_BURN_ADDRESS).call{value: amount}("");
        if (!success) revert ForwardFailed();

        // Mint BETH after successful forwarding
        _mint(recipient, amount);
        _totalBurned += amount;

        emit Burned(msg.sender, amount);
        emit Minted(recipient, amount);

        return amount;
    }
}
```

## Copyright
Copyright and related rights waived via [CC0](../LICENSE.md).
