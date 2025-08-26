// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { BETH } from "src/BETH.sol";

contract MainnetForkTests is Test {
    address internal constant BURN = address(0x0000000000000000000000000000000000000000);
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
        // Fund alice and create some BETH
        uint256 amount = 1 ether;
        address alice = address(0xA11CE);
        vm.deal(alice, amount);
        vm.prank(alice);
        beth.deposit{ value: amount }();

        uint256 burnETHBefore = BURN.balance;

        // Transfer tokens between non-burn addresses - ERC20 operations should not affect burn address ETH
        address recipient = address(0xB0B);
        vm.prank(alice);
        beth.approve(address(this), amount);

        // Pull tokens from alice to recipient via this contract
        beth.transferFrom(alice, recipient, amount);

        // ETH at burn address must not change due to ERC-20 operations
        assertEq(BURN.balance, burnETHBefore, "ERC20 ops must not move ETH from burn");
    }
}
