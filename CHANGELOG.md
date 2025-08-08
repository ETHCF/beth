# Changelog

All notable changes to this project will be documented in this file.

This project adheres to semantic versioning.

## [1.0.0] - 2025-08-08

### Added
- BETH ERC-20 token implementation (`src/BETH.sol`) based on OpenZeppelin ERC20
  - Hardcoded ETH burn address: `0x000000000000000000000000000000000000dEaD`
  - `deposit()` payable: forwards `msg.value` ETH to burn address, mints BETH 1:1 to `msg.sender`
  - `depositTo(address recipient)` payable: forwards ETH to burn address, mints to `recipient`
  - `receive()` payable: forwards ETH to burn address, mints to `msg.sender`
  - `flush()` permissionless: sweeps any forced ETH balance to burn address without minting
  - `totalBurned()` view: total ETH forwarded to burn address (including flushes)
  - Decimals fixed at 18; no ownership, no upgradeability, no privileged access
  - Events: `Burned(from, amount)`, `Minted(to, amount)`; Errors: `ZeroDeposit`, `ForwardFailed`
  - Solidity 0.8.24, optimizer enabled, gas-efficient patterns

### Tests
- Unit tests (`test/unit/`)
  - Core: deposits, depositTo, receive, ZeroDeposit reverts, events ordering and args, decimals
  - ERC-20 conformance: transfer, transferFrom, allowances, zero-address checks
  - Burn forwarding: formalized success to EOAs; artificial failure harness for revert path
  - Gas unit: bounds for `deposit`, `depositTo`, `receive`
- Fuzz tests (`test/fuzz/`)
  - Randomized senders/recipients/amounts, shadow ledger, event accounting, sequential deposits
  - Sender edge cases: callers that revert after calling BETH; callers that selfdestruct mid-sequence
- Invariant tests (`test/invariants/`)
  - Handlers for deposit/depositTo/receive/transfer/approve/transferFrom
  - Invariants: `totalSupply == totalBurned`; sum(balances) == totalSupply; only mint paths are deposit/receive; contract balance bounded by forced ETH
- Exploit/forced ETH tests (`test/exploits/`)
  - `ExploitForceETH` helper using `selfdestruct` to force ETH to contract
  - Assert forced ETH does not mint; after legit deposits, contract balance equals prior forced ETH only
  - `flush()` sweeps forced ETH to burn address without minting
- Mainnet fork tests
  - Burn address has no code and historical non-zero balance; live deposit increases burn balance by `msg.value`
  - ERC-20 ops cannot move ETH from burn address
- Event accounting helpers
  - Parse `Burned`/`Minted` logs to recompute expected deltas and assert equality with storage

### Tooling & CI
- `foundry.toml`: `solc_version = 0.8.24`, optimizer enabled (`optimizer_runs = 200`), pinned dependencies
- Scripts: `scripts/ci-local.sh`, `scripts/check_selectors.sh`, `scripts/justforge.sh`
- Makefile targets for build/test/coverage/slither/inspect
- CI (`.github/workflows/ci.yml`): format, build, test with gas report, Slither (fail on MEDIUM+), coverage gates (≥95% total, 100% for `src/BETH.sol`)
- Slither configuration `slither.config.json` to reduce noise and enforce gates
- Solhint configuration `.solhint.json` with NatSpec enforcement
- Gas report and snapshot support

### Documentation
- `architecture.md` and `beth-standard.md`: updated to include reference implementation and `flush()` as optional maintenance function
- `README.md`: overview, how it works, example usage (Solidity and CLI), security notes (forced ETH limitation), license
- `SECURITY.md`: responsible disclosure policy
- `CONTRIBUTING.md`: setup, coding standards, testing and analysis workflow

### Known Limitations
- Forced ETH via `selfdestruct` can reside temporarily in the contract; no BETH is minted for it. `flush()` sweeps it to the burn address without minting.