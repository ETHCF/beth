# BETH Architecture

## Overview
BETH is an immutable ERC-20 token representing provably burnt ETH.  
Sending ETH to the contract mints an equal amount of BETH and forwards the ETH to the Ethereum burn address (`0x000000000000000000000000000000000000dEaD`).  
BETH is fully permissionless, non-redeemable, and cannot be altered after deployment.

## Core Mechanics
- Mint ratio: 1 BETH per 1 ETH
- ETH is sent directly to the burn address on receipt
- No upgradeability, no admin keys, no privileged functions
- ERC-20 `decimals` fixed at 18
- Supports direct ETH transfers via `receive()` to mint BETH to sender
- Optional `depositTo(address)` for minting to a different address

## Functions
- `deposit() external payable` – Mint BETH to sender
- `depositTo(address recipient) external payable` – Mint BETH to a specified recipient
- `totalBurned() external view returns (uint256)` – Total ETH permanently destroyed
- Standard ERC-20 functions: `totalSupply()`, `balanceOf()`, `transfer()`, `approve()`, `transferFrom()`

## Events
- `Burned(address indexed from, uint256 amount)`
- `Minted(address indexed to, uint256 amount)`
- Standard ERC-20 `Transfer` and `Approval`

## Deployment Requirements
- No ownership or role-based access control
- No upgrade proxy or self-destruct
- Constructor finalizes configuration and deployer keys are burned
- If deployed via a factory, factory must be destroyed after deployment

## Security Notes
- ETH burn address hardcoded in contract
- No ETH retained in contract
- Minting only through payable deposit functions
- Stateless logic to avoid reentrancy
