#!/usr/bin/env bash
set -euo pipefail

# Usage: BETH_ADDRESS=0x... CHAIN_ID=1 ETHERSCAN_API_KEY=... ./scripts/verify.sh

if [[ -z "${BETH_ADDRESS:-}" || -z "${CHAIN_ID:-}" || -z "${ETHERSCAN_API_KEY:-}" ]]; then
  echo "Missing env. Required: BETH_ADDRESS, CHAIN_ID, ETHERSCAN_API_KEY" >&2
  exit 1
fi

forge verify-contract \
  --chain-id ${CHAIN_ID} \
  --num-of-optimizations 200 \
  --watch \
  ${BETH_ADDRESS} \
  src/BETH.sol:BETH \
  --etherscan-api-key ${ETHERSCAN_API_KEY}
