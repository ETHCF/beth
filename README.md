```
                       )  
   (         *   )  ( /(  
 ( )\  (   ` )  /(  )\()) 
 )((_) )\   ( )(_))((_)\  
((_)_ ((_) (_(_())  _((_) 
 | _ )| __||_   _| | || | 
 | _ \| _|   | |   | __ | 
 |___/|___|  |_|   |_||_| 
 ```

# BETH — Burned ETH (Proof of Burn)

## Overview
BETH is an immutable ERC‑20 token representing provably burned ETH. Sending ETH to the contract mints BETH 1:1 and forwards the ETH to the canonical burn address `0x0000000000000000000000000000000000000000`.

- No admin keys
- Non-upgradeable
- Non‑redeemable
- OpenZeppelin ERC20 base
- Solidity 0.8.24

## How it works
- deposit()/receive(): mints BETH to `msg.sender` and forwards ETH to the burn address
- depositTo(address): mints to `recipient`, forwards ETH to the burn address
- totalSupply() == totalBurned() at all times
- flush(): forwards any force‑sent ETH to the burn address without minting; increments totalBurned()

Key properties
- Decimals: 18
- Mint ratio: 1 BETH per 1 wei of ETH
- Burn address: `0x0000000000000000000000000000000000000000`

## Deployment addresses
- Mainnet: [0x2cb662Ec360C34a45d7cA0126BCd53C9a1fd48F9](https://etherscan.io/address/0x2cb662Ec360C34a45d7cA0126BCd53C9a1fd48F9)
- Sepolia/Holesky: TBA

## Example usage

### Solidity
```solidity
interface IBETH {
    function deposit() external payable;
    function depositTo(address recipient) external payable;
    function totalBurned() external view returns (uint256);
}

contract Example {
    IBETH public immutable beth;

    constructor(address bethAddress) { beth = IBETH(bethAddress); }

    function burnMyETH() external payable {
        // Mints BETH to this contract and forwards ETH to burn address
        beth.deposit{value: msg.value}();
    }

    function giftBurn(address recipient) external payable {
        // Mints BETH to recipient and forwards ETH to burn address
        beth.depositTo{value: msg.value}(recipient);
    }
}
```

### CLI (Foundry)
- Build: `forge build`
- Test with gas report: `forge test --gas-report`
- Scripts:
  - Deploy: `forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --broadcast`
  - Deposit: `forge script script/Deposit.s.sol:DepositScript --rpc-url $RPC_URL --broadcast`
  - DepositTo: `forge script script/DepositTo.s.sol:DepositToScript --rpc-url $RPC_URL --broadcast`
  - Query totalBurned: `forge script script/QueryTotalBurned.s.sol:QueryTotalBurned`

## Security notes & known limitations
- No ownership or privileged roles
- Forwarding is atomic; if ETH forwarding to burn address fails, the tx reverts (no mint)
- Forced ETH: contracts can force‑send ETH (e.g., via selfdestruct) to BETH without calling it. This ETH is not minted to anyone and remains on the contract. The permissionless `flush()` function forwards such ETH to the burn address and increments `totalBurned()` without minting.

## Attribution
Built by [Zak Cole](https://x.com/0xzak) at [Number Group](https://numbergroup.xyz) for the [Ethereum Community Foundation](https://ethcf.org).

## Audits & analysis
- Static analysis (Slither) in CI; CI fails on Medium+ findings
- Invariants and fuzz tests ensure `totalSupply() == totalBurned()`, no ETH retention except force‑sent ETH, and minting only via `deposit`, `depositTo`, or `receive`

## License
MIT. See LICENSE.