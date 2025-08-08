#!/usr/bin/env bash
set -euo pipefail

: "${ETHERSCAN_API_KEY:?set ETHERSCAN_API_KEY}"
: "${CHAIN_ID:?set CHAIN_ID}"
: "${ADDR:?set ADDR}"

forge verify-contract --chain-id "$CHAIN_ID" "$ADDR" src/BETH.sol:BETH "$ETHERSCAN_API_KEY"


