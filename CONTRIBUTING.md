# Contributing

Thanks for your interest in contributing to BETH. This guide explains how to set up the repo, coding standards, testing, and analysis tooling.

## Repo setup
1. Install Foundry: https://book.getfoundry.sh/getting-started/installation
2. Clone and enter the project directory.
3. Install dependencies:
   - `forge install`
   - Or `make install`
4. Build & test:
   - `forge build`
   - `forge test -vvv`

## Coding standards
- Solidity 0.8.24 (see `foundry.toml`)
- Full NatSpec for contracts/functions/events/errors:
  - `@title`, `@notice`, `@dev`, `@param`, `@return` where applicable
- Use OpenZeppelin primitives where appropriate
- No ownership, no upgradeability, no privileged access
- Keep code minimal, explicit, and readable; avoid unnecessary complexity
 - All Solidity files must use MIT SPDX. Keep a single SPDX header at the top.

## Tests layout
- Unit: `test/unit/*.t.sol`
- Fuzz: `test/fuzz/*.t.sol`
- Invariants: `test/invariants/*.t.sol`
- Exploits/edge: `test/exploits/*.t.sol`

## Useful commands
- Run all tests with gas report: `forge test --gas-report`
- Match by contract/test name: `forge test --match-contract BETH --match-test test_Deposit`
- Snapshot gas: `forge snapshot`
- Coverage (lcov): `forge coverage --report lcov`
- Mainnet fork (set `RPC_URL`): `RPC_URL=$RPC_URL forge test --match-contract MainnetFork`

## Analysis tools
   - Slither (static analysis):
     - Install: `pip3 install slither-analyzer solc-select && solc-select install 0.8.24 && solc-select use 0.8.24`
     - Run: `slither . --config-file slither.config.json`
- Solhint (NatSpec/style):
  - Install: `npm i -g solhint` or use `npx --yes solhint`
   - Run: `npx --yes solhint -f table "src/**/*.sol" "test/**/*.sol"`
- Format: `forge fmt --check` (or `make fmt`)
- Local CI bundle: `scripts/ci-local.sh` (or `make ci-local`)
- Selector surface check: `scripts/check_selectors.sh`

## Environment
- Copy `.env.example` to `.env` and set:
  - `RPC_URL`, `PRIVATE_KEY`, `ETHERSCAN_API_KEY`, `BETH_ADDRESS`

## CI
GitHub Actions runs formatting, build, tests with gas report, Slither (fails on Medium+), and coverage enforcement (≥95% total lines, 100% for `src/BETH.sol`).

## Commit style
- Keep commits focused and descriptive
- Include tests for behavior changes
- Ensure `forge test` passes and no new Slither/Solhint issues

