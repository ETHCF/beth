// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { BETH } from "src/BETH.sol";

contract MainnetForkTests is Test {
    address internal constant BURN = address(0x000000000000000000000000000000000000dEaD);
    BETH internal beth;

    function setUp() public {
        // Prefer env var MAINNET_RPC_URL; fall back to user-provided URL
        string memory url;
        try vm.envString("MAINNET_RPC_URL") returns (string memory u) {
            url = u;
        } catch {
            url = "https://eth-mainnet.g.alchemy.com/v2/PY43TisJEUzXSaHkFRLv8";
        }
        vm.createSelectFork(url);
        beth = new BETH();
    }

    function test_BurnAddress_NoCode_AndNonZeroBalance() public view {
        assertEq(BURN.code.length, 0, "burn has code on mainnet fork");
        assertGt(BURN.balance, 0, "burn balance should be > 0 historically");
    }

    function test_Deposit_IncreasesBurnBalance_OnFork() public {
        uint256 burnBefore = BURN.balance;
        uint256 contractBefore = address(beth).balance;

        address alice = address(0xA11CE);
        uint256 amount = 0.2 ether;
        vm.deal(alice, amount);

        vm.prank(alice);
        beth.deposit{ value: amount }();

        assertEq(BURN.balance, burnBefore + amount, "burn balance must increase by msg.value");
        // Contract balance should not change due to deposit (forced ETH, if any, remains unchanged)
        assertEq(
            address(beth).balance, contractBefore, "contract balance must be unchanged by deposit"
        );
    }

    function test_ERC20_Ops_DoNotMoveETH_FromBurn() public {
        // Send some BETH to the burn address to allow approvals/transfers
        uint256 amount = 1 ether;
        address funder = address(0xF00D);
        vm.deal(funder, amount);
        vm.prank(funder);
        beth.depositTo{ value: amount }(BURN);

        uint256 burnETHBefore = BURN.balance;

        // From burn address, set an allowance and transfer tokens out
        address recipient = address(0xB0B);
        vm.prank(BURN);
        beth.approve(address(this), amount);

        // Pull tokens from burn to recipient
        beth.transferFrom(BURN, recipient, amount);

        // ETH at burn address must not change due to ERC-20 operations
        assertEq(BURN.balance, burnETHBefore, "ERC20 ops must not move ETH from burn");
    }
}
