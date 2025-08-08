#!/usr/bin/env bash
set -euo pipefail

echo "==> fmt"
forge fmt --check

echo "==> build"
forge build --sizes

echo "==> test"
forge test --gas-report

echo "==> snapshot"
forge snapshot

echo "==> coverage"
forge coverage --report lcov

echo "==> slither"
if command -v slither >/dev/null 2>&1; then
  slither . --config-file slither.config.json
else
  echo "slither not found; skipping"
fi


