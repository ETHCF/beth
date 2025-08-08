#!/usr/bin/env bash
set -euo pipefail

echo "==> Format check"
forge fmt --check

echo "==> Build"
forge build --sizes

echo "==> Test with gas report"
forge test --gas-report

echo "==> Coverage (lcov)"
forge coverage --report lcov

if command -v lcov >/dev/null 2>&1; then
  total=$(lcov --summary lcov.info | awk '/lines/ {print $2}' | sed 's/%//')
  echo "Total coverage: $total%"
else
  echo "lcov not installed; cannot compute total coverage percentage"
  exit 1
fi

echo "==> Enforce coverage thresholds (>=95% total, 100% for src/BETH.sol)"

# Compute BETH.sol line coverage percentage from lcov.info
beth=$(grep -n "SF:src/BETH.sol" -n lcov.info >/dev/null 2>&1 && awk '
  $0 ~ /^SF:src\/BETH.sol$/ { in_beth=1; lf=0; lh=0 }
  in_beth && $0 ~ /^LF:/ { sub("LF:","",$0); lf=$0 }
  in_beth && $0 ~ /^LH:/ { sub("LH:","",$0); lh=$0 }
  in_beth && $0 ~ /^end_of_record$/ { in_beth=0; if (lf>0) printf("%.2f", (lh*100)/lf); else printf("0.00") }
' lcov.info)

echo "BETH.sol coverage: ${beth:-0}%"

bc -l <<< "$total >= 95" | grep -q 1 || { echo "Coverage below 95%"; exit 1; }
bc -l <<< "${beth:-0} == 100" | grep -q 1 || { echo "BETH.sol coverage not 100%"; exit 1; }

echo "==> Slither"
if ! command -v slither >/dev/null 2>&1; then
  echo "slither is not installed. Install via: pipx install slither-analyzer or pip3 install slither-analyzer"
  exit 1
fi
slither . --config-file slither.config.json --json slither.json || true

if command -v jq >/dev/null 2>&1; then
  jq '.results | .detectors[] | select(.impact=="Medium" or .impact=="High" or .impact=="Critical")' slither.json > findings.json || true
  if [ -s findings.json ]; then
    echo "Slither found Medium+ issues:" && cat findings.json
    exit 1
  fi
else
  echo "jq is not installed; cannot automatically filter slither results"
  exit 1
fi

echo "==> ABI/Selectors and payable function check"
scripts/check_selectors.sh

echo "==> solhint (NatSpec enforcement)"
if command -v npx >/dev/null 2>&1; then
  npx --yes solhint -f table "src/**/*.sol" "test/**/*.sol"
else
  echo "npx/solhint not found; install Node.js and solhint to enforce NatSpec"; exit 1
fi

echo "==> ABI/bytecode size checks"
forge build > /dev/null
ABI_LEN=$(forge inspect src/BETH.sol:BETH abi | wc -c | tr -d ' ')
BYTECODE_LEN=$(forge inspect src/BETH.sol:BETH bytecode | wc -c | tr -d ' ')
DEPLOY_LEN=$(forge inspect src/BETH.sol:BETH deployedBytecode | wc -c | tr -d ' ')
echo "ABI bytes: $ABI_LEN"
echo "Creation bytecode chars: $BYTECODE_LEN"
echo "Deployed bytecode chars: $DEPLOY_LEN"
THRESH=50000
if [ "$DEPLOY_LEN" -gt "$THRESH" ]; then echo "Deployed bytecode too large ($DEPLOY_LEN > $THRESH)"; exit 1; fi

echo "All local CI checks passed."


