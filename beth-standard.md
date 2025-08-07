## BETH Standard: Proof-of-Burn ERC-20

**Author**: Zak Cole, zcole@linux.com, Ethereum Community Foundation
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
- **Name**: `Burnt ETH – Proof of Burn`
- **Decimals**: `18`
- **Mint Ratio**: `1 BETH : 1 ETH`
- **Burn Address**: `0x000000000000000000000000000000000000dEaD`
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

#### Events
- `Burned(address indexed from, uint256 amount)`
- `Minted(address indexed to, uint256 amount)`
- Standard ERC-20 `Transfer` and `Approval`.

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

### Reference Implementation
[To be provided in separate file; should use OpenZeppelin ERC-20 base, follow immutability requirements, and match this specification exactly.]

### Licensing
CC0 or equivalent public domain dedication.
