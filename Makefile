.PHONY: install build test snapshot deploy deposit depositTo query verify gas fmt lint coverage slither inspect ci-local

install:
	forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 foundry-rs/forge-std@v1.9.5 | cat

build:
	forge build | cat

test:
	forge test -vvv | cat

fmt:
	forge fmt --check | cat

lint:
	forge fmt --check | cat

snapshot:
	forge snapshot | cat

deploy:
	@if [ -z "$$RPC_URL" ] || [ -z "$$PRIVATE_KEY" ]; then echo "RPC_URL and PRIVATE_KEY are required"; exit 1; fi
	forge script script/Deploy.s.sol:Deploy --rpc-url $$RPC_URL --broadcast -vvvv | cat

deposit:
	@if [ -z "$$RPC_URL" ] || [ -z "$$PRIVATE_KEY" ] || [ -z "$$BETH_ADDRESS" ] || [ -z "$$DEPOSIT_AMOUNT_WEI" ]; then echo "RPC_URL, PRIVATE_KEY, BETH_ADDRESS, DEPOSIT_AMOUNT_WEI required"; exit 1; fi
	forge script script/Deposit.s.sol:DepositScript --rpc-url $$RPC_URL --broadcast -vvvv | cat

depositTo:
	@if [ -z "$$RPC_URL" ] || [ -z "$$PRIVATE_KEY" ] || [ -z "$$BETH_ADDRESS" ] || [ -z "$$DEPOSIT_AMOUNT_WEI" ] || [ -z "$$RECIPIENT" ]; then echo "RPC_URL, PRIVATE_KEY, BETH_ADDRESS, DEPOSIT_AMOUNT_WEI, RECIPIENT required"; exit 1; fi
	forge script script/DepositTo.s.sol:DepositToScript --rpc-url $$RPC_URL --broadcast -vvvv | cat

query:
	@if [ -z "$$BETH_ADDRESS" ]; then echo "BETH_ADDRESS required"; exit 1; fi
	forge script script/QueryTotalBurned.s.sol:QueryTotalBurned -vvvv | cat

verify:
	@if [ -z "$$BETH_ADDRESS" ] || [ -z "$$CHAIN_ID" ] || [ -z "$$ETHERSCAN_API_KEY" ]; then echo "BETH_ADDRESS, CHAIN_ID, ETHERSCAN_API_KEY required"; exit 1; fi
	bash scripts/verify.sh | cat

gas:
	forge test --gas-report | cat

coverage:
	forge coverage --report lcov | cat

slither:
	slither . --config-file slither.config.json | cat

inspect:
	forge inspect src/BETH.sol:BETH methods | cat

ci-local:
	bash scripts/ci-local.sh

.PHONY: update-golden
update-golden:
	@echo "==> Refresh ABI snapshot"
	forge inspect src/BETH.sol:BETH abi > abi/BETH.json
	@echo "==> Compute runtime code hash"
	@HASH=$$(cast keccak $$(jq -r '.deployedBytecode.object' out/BETH.sol/BETH.json)); \
	 sed -i '' "s/hex\"[0-9a-f]*\"/hex\"$${HASH#0x}\"/" test/unit/BETHBytecodeHash.t.sol; \
	 echo "Updated runtime code hash: $$HASH"

