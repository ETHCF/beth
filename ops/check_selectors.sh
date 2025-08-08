#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for selector checks" && exit 1
fi

echo "==> forge inspect methods"
forge inspect src/BETH.sol:BETH methods | tee methods.txt

echo "==> forge inspect abi"
forge inspect src/BETH.sol:BETH abi > abi.json

echo "==> filter external functions"
jq -r '.[] | select(.type=="function") | [.name, (.stateMutability//""), (.inputs|length)] | @tsv' abi.json > functions.tsv
cat functions.tsv

echo "==> enforce only expected externals and payables"
# Expected: standard ERC20 externals + BETH functions
expected=(deposit depositTo flush totalBurned totalSupply balanceOf transfer approve transferFrom allowance name symbol decimals)

while IFS=$'\t' read -r name mut _; do
  found=false
  for e in "${expected[@]}"; do
    if [[ "$name" == "$e" ]]; then found=true; break; fi
  done
  if [[ "$found" == false ]]; then
    echo "Unexpected external function: $name"
    exit 1
  fi
  if [[ "$name" == "deposit" || "$name" == "depositTo" ]]; then
    if [[ "$mut" != "payable" ]]; then
      echo "$name must be payable (got $mut)" && exit 1
    fi
  fi
done < <(jq -r '.[] | select(.type=="function") | [.name, .stateMutability] | @tsv' abi.json)

echo "Selector checks OK"


