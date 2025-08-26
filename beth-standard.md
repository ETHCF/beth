## BETH Standard: Proof-of-Burn ERC-20

**Author**: Built by Zak Cole (x.com/0xzak, github.com/zscole) at Number Group for the Ethereum Community Foundation.
**Status**: Draft  
**Type**: Standards Track  
**Category**: ERC  
**Created**: 2025-08-07

### Abstract
BETH is an ERC-20 token representing ETH that has been permanently removed from circulation via onchain burn. ETH sent to the BETH contract is forwarded to the Ethereum burn address and an equal amount of BETH is minted to the sender or a designated recipient. BETH is immutable, permissionless, and non-redeemable.

### Motivation
Wrapped Ether (WETH) became a foundational ERC-20 primitive by providing a standard, composable interface for ETH. BETH extends this pattern to ETH burning, providing a canonical and composable representation of provably destroyed ETH. This enables protocols to integrate burn-based mechanics without reinventing verification or tokenization.

### Specification

#### Contract Properties
- **Symbol**: `BETH`
 - **Name**: `BETH`
- **Decimals**: `18`
- **Mint Ratio**: `1 BETH : 1 ETH`
- **Burn Address**: `0x0000000000000000000000000000000000000000`
- **Upgradeability**: None
- **Access Control**: None (no ownership or privileged roles)
- **Redemption**: None (irreversible)

#### External Functions
- `deposit() external payable`  
  Mints `msg.value` BETH to `msg.sender` and forwards ETH to burn address.

- `depositTo(address recipient) external payable`  
  Mints `msg.value` BETH to `recipient` and forwards ETH to burn address.

- `receive() external payable`  
  Equivalent to `deposit()`.

- `totalBurned() external view returns (uint256)`  
  Returns the total ETH permanently destroyed through the contract.

- **Standard ERC-20 interface**:  
  `totalSupply()`, `balanceOf()`, `transfer()`, `approve()`, `transferFrom()`, and related events.

#### Optional Maintenance Function
- `flush() external`  
  Permissionless function that forwards any ETH balance held by the contract (e.g., due to forced ETH via `SELFDESTRUCT`) to the burn address. This function does not mint BETH. It increases `totalBurned` by the forwarded amount and emits `Burned(address(this), amount)`.

#### Events
- `Burned(address indexed from, uint256 amount)`
- `Minted(address indexed to, uint256 amount)`
- Standard ERC-20 `Transfer` and `Approval`.

#### Errors
- `ZeroDeposit()` – Reverts when `msg.value == 0` on deposit.
- `ForwardFailed()` – Reverts if forwarding ETH to the burn address fails.

### Rationale
By mirroring WETH’s simplicity and standardization while representing a permanent action (burn), BETH ensures:
- Predictable integration points for protocols.
- Transparent and verifiable burn metrics.
- Zero custody or redemption logic, reducing complexity and attack surface.
- No governance or upgrade mechanisms, preserving immutability.

### Security Considerations
- ETH is forwarded to a hardcoded burn address to eliminate custody risk.
- Contract holds no ETH; reentrancy is not possible in mint logic.
- Minting is only possible via payable deposit functions.
 - ETH may be force-sent to the contract via `SELFDESTRUCT` by external contracts. If implemented, `flush()` forwards any such stray ETH to the burn address without minting BETH. If not implemented, such ETH remains stranded and is not reflected in `totalBurned()`.

### Reference Implementation
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
    address public constant ETH_BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

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
        (bool success, ) = payable(ETH_BURN_ADDRESS).call{value: amount}("");
        if (!success) revert ForwardFailed();
        _totalBurned += amount;
        emit Burned(address(this), amount);
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

### Licensing
CC0 or equivalent public domain dedication.
