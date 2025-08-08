// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BETH} from "src/BETH.sol";

contract BatchDepositor {
    // Splits msg.value across n calls and invokes deposit
    function batchDeposit(address payable bethAddr, uint256 n) external payable {
        require(n > 0, "n=0");
        uint256 per = msg.value / n;
        require(per > 0, "per=0");
        uint256 sent;
        for (uint256 i = 0; i < n - 1; i++) {
            (bool ok, ) = bethAddr.call{value: per}(abi.encodeWithSelector(BETH.deposit.selector));
            require(ok, "deposit failed");
            sent += per;
        }
        uint256 last = msg.value - sent;
        (bool ok2, ) = bethAddr.call{value: last}(abi.encodeWithSelector(BETH.deposit.selector));
        require(ok2, "deposit failed(last)");
    }

    // Splits msg.value across n calls and invokes depositTo(recipient)
    function batchDepositTo(address payable bethAddr, address recipient, uint256 n) external payable {
        require(n > 0, "n=0");
        uint256 per = msg.value / n;
        require(per > 0, "per=0");
        uint256 sent;
        for (uint256 i = 0; i < n - 1; i++) {
            (bool ok, ) = bethAddr.call{value: per}(abi.encodeWithSelector(BETH.depositTo.selector, recipient));
            require(ok, "depositTo failed");
            sent += per;
        }
        uint256 last = msg.value - sent;
        (bool ok2, ) = bethAddr.call{value: last}(abi.encodeWithSelector(BETH.depositTo.selector, recipient));
        require(ok2, "depositTo failed(last)");
    }
}

contract BETHBatchAndLimitsTest is Test {
    BETH internal beth;
    BatchDepositor internal batch;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal constant BURN = address(0x000000000000000000000000000000000000dEaD);

    function setUp() public {
        beth = new BETH();
        batch = new BatchDepositor();
    }

    // 1) Very large deposit amounts should succeed (no OOG due to logs)
    function test_Deposit_VeryLargeAmounts_NoOOG() public {
        uint256[4] memory amounts = [
            uint256(1 ether),
            uint256(1e24),
            uint256(1e30),
            uint256(type(uint128).max) // huge but within uint256
        ];

        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 amount = amounts[i];
            vm.deal(alice, amount);

            uint256 burnBefore = BURN.balance;
            uint256 totalSupplyBefore = beth.totalSupply();
            uint256 totalBurnedBefore = beth.totalBurned();

            vm.prank(alice);
            beth.deposit{value: amount}();

            assertEq(BURN.balance, burnBefore + amount);
            assertEq(beth.totalSupply(), totalSupplyBefore + amount);
            assertEq(beth.totalBurned(), totalBurnedBefore + amount);
            assertEq(address(beth).balance, 0);
        }
    }

    // 2) Multiple deposits within a single transaction via helper
    function test_BatchDeposit_Deposit_AdditiveCorrectness() public {
        uint256 n = 64;
        uint256 per = 0.25 ether;
        uint256 total = n * per;

        vm.deal(alice, total);
        uint256 burnBefore = BURN.balance;
        uint256 totalSupplyBefore = beth.totalSupply();
        uint256 totalBurnedBefore = beth.totalBurned();

        vm.prank(alice);
        batch.batchDeposit{value: total}(payable(address(beth)), n);

        assertEq(BURN.balance, burnBefore + total);
        assertEq(beth.totalSupply(), totalSupplyBefore + total);
        assertEq(beth.totalBurned(), totalBurnedBefore + total);
        // deposit() mints to caller, which is the batch helper in this test
        assertEq(beth.balanceOf(address(batch)), total);
        assertEq(beth.balanceOf(alice), 0);
        assertEq(address(beth).balance, 0);
    }

    function test_BatchDeposit_DepositTo_AdditiveCorrectness() public {
        uint256 n = 32;
        uint256 per = 1 ether;
        uint256 total = n * per;

        vm.deal(alice, total);
        uint256 burnBefore = BURN.balance;
        uint256 totalSupplyBefore = beth.totalSupply();
        uint256 totalBurnedBefore = beth.totalBurned();
        uint256 recipientBefore = beth.balanceOf(bob);

        vm.prank(alice);
        batch.batchDepositTo{value: total}(payable(address(beth)), bob, n);

        assertEq(BURN.balance, burnBefore + total);
        assertEq(beth.totalSupply(), totalSupplyBefore + total);
        assertEq(beth.totalBurned(), totalBurnedBefore + total);
        assertEq(beth.balanceOf(bob), recipientBefore + total);
        assertEq(address(beth).balance, 0);
    }

    // 3) Fuzz with uint96 amounts, verify totalBurned tracks sum without overflow
    function testFuzz_NoOverflow_TotalBurned_WithUint96(address s1, address s2, address s3, uint96 a, uint96 b, uint96 c) public {
        vm.assume(s1 != address(0) && s2 != address(0) && s3 != address(0));
        vm.assume(s1 != BURN && s2 != BURN && s3 != BURN);
        vm.assume(a > 0 && b > 0 && c > 0);

        uint256 burnBefore = beth.totalBurned();
        uint256 supplyBefore = beth.totalSupply();

        vm.deal(s1, a);
        vm.prank(s1);
        beth.deposit{value: a}();

        vm.deal(s2, b);
        vm.prank(s2);
        beth.deposit{value: b}();

        vm.deal(s3, c);
        vm.prank(s3);
        beth.deposit{value: c}();

        uint256 sum = uint256(a) + uint256(b) + uint256(c);
        assertEq(beth.totalBurned(), burnBefore + sum);
        assertEq(beth.totalSupply(), supplyBefore + sum);

        // Also try a near-upper-bound uint96 value in isolation
        address s4 = address(0x4444);
        uint96 big = type(uint96).max;
        vm.deal(s4, big);
        uint256 burnMid = beth.totalBurned();
        uint256 supplyMid = beth.totalSupply();
        vm.prank(s4);
        beth.deposit{value: big}();
        assertEq(beth.totalBurned(), burnMid + big);
        assertEq(beth.totalSupply(), supplyMid + big);
    }
}


