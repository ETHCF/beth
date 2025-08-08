#!/usr/bin/env bash
set -euo pipefail

# Local audit pack runner
# Requirements: foundry, slither, solhint, jq

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

export PATH="$HOME/Library/Python/3.9/bin:$PATH"

echo "==> forge fmt --check"
forge fmt --check

echo "==> forge build --sizes"
forge build --sizes

echo "==> solhint (src and test)"
npx --yes solhint -f table "src/**/*.sol" "test/**/*.sol"

if command -v slither >/dev/null 2>&1; then
  echo "==> slither"
  slither . --config-file slither.config.json
else
  echo "WARN: slither not found on PATH; skipping"
fi

echo "==> forge test --gas-report"
forge test --gas-report | tee gas-report.txt | cat

echo "==> forge coverage --report lcov"
forge coverage --report lcov

echo "==> scripts/check_selectors.sh"
./scripts/check_selectors.sh

echo "Audit pack complete"
