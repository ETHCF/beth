// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { BETH } from "src/BETH.sol";

contract BETHFuzzSuite is Test {
    BETH internal beth;
    address internal constant BURN = address(0x0000000000000000000000000000000000000000);

    // Shadow ledger
    mapping(address => uint256) internal expectedBalance;
    uint256 internal expectedTotalSupply;
    uint256 internal expectedTotalBurned;

    function setUp() public {
        beth = new BETH();
    }

    function testFuzz_Deposit_ShadowLedger(address sender, uint96 amount) public {
        vm.assume(sender != address(0) && sender != BURN);
        vm.assume(amount > 0);
        vm.deal(sender, amount);

        vm.prank(sender);
        beth.deposit{ value: amount }();

        expectedBalance[sender] += amount;
        expectedTotalSupply += amount;
        expectedTotalBurned += amount;

        assertEq(beth.balanceOf(sender), expectedBalance[sender]);
        assertEq(beth.totalSupply(), expectedTotalSupply);
        assertEq(beth.totalBurned(), expectedTotalBurned);
        assertEq(address(beth).balance, 0);
    }

    function testFuzz_DepositTo_ShadowLedger(address from, address to, uint96 amount) public {
        vm.assume(from != address(0) && from != BURN);
        vm.assume(to != address(0) && to != BURN);
        vm.assume(amount > 0);
        vm.deal(from, amount);

        vm.prank(from);
        beth.depositTo{ value: amount }(to);

        expectedBalance[to] += amount;
        expectedTotalSupply += amount;
        expectedTotalBurned += amount;

        assertEq(beth.balanceOf(to), expectedBalance[to]);
        assertEq(beth.totalSupply(), expectedTotalSupply);
        assertEq(beth.totalBurned(), expectedTotalBurned);
        assertEq(address(beth).balance, 0);
    }

    function testFuzz_Sequence_DepositAndDepositTo(
        address s1,
        address s2,
        address r1,
        uint96 a1,
        uint96 a2
    ) public {
        vm.assume(s1 != address(0) && s1 != BURN);
        vm.assume(s2 != address(0) && s2 != BURN);
        vm.assume(r1 != address(0) && r1 != BURN);
        vm.assume(a1 > 0 && a2 > 0);

        vm.deal(s1, a1);
        vm.prank(s1);
        beth.deposit{ value: a1 }();
        expectedBalance[s1] += a1;
        expectedTotalSupply += a1;
        expectedTotalBurned += a1;

        vm.deal(s2, a2);
        vm.prank(s2);
        beth.depositTo{ value: a2 }(r1);
        expectedBalance[r1] += a2;
        expectedTotalSupply += a2;
        expectedTotalBurned += a2;

        // Assert shadow matches on-chain for tracked actors
        assertEq(beth.totalSupply(), expectedTotalSupply);
        assertEq(beth.totalBurned(), expectedTotalBurned);
        assertEq(beth.balanceOf(s1), expectedBalance[s1]);
        assertEq(beth.balanceOf(r1), expectedBalance[r1]);
        assertEq(address(beth).balance, 0);
    }

    function test_EdgeCases_ZeroAddressRecipient_Reverts(address from, uint96 amount) public {
        vm.assume(from != address(0) && from != BURN);
        vm.assume(amount > 0);
        vm.deal(from, amount);
        vm.prank(from);
        vm.expectRevert();
        beth.depositTo{ value: amount }(address(0));
    }

    function test_EdgeCases_ZeroValue_Reverts(address from) public {
        vm.assume(from != address(0) && from != BURN);
        vm.prank(from);
        vm.expectRevert(BETH.ZeroDeposit.selector);
        beth.deposit{ value: 0 }();
        vm.prank(from);
        vm.expectRevert(BETH.ZeroDeposit.selector);
        beth.depositTo{ value: 0 }(from);
    }

    function testFuzz_MultipleSequentialDeposits(address user, uint96 a1, uint96 a2, uint96 a3)
        public
    {
        vm.assume(user != address(0) && user != BURN);
        vm.assume(a1 > 0 && a2 > 0 && a3 > 0);

        vm.deal(user, uint256(a1) + uint256(a2) + uint256(a3));

        vm.prank(user);
        beth.deposit{ value: a1 }();
        expectedBalance[user] += a1;
        expectedTotalSupply += a1;
        expectedTotalBurned += a1;

        vm.prank(user);
        beth.deposit{ value: a2 }();
        expectedBalance[user] += a2;
        expectedTotalSupply += a2;
        expectedTotalBurned += a2;

        vm.prank(user);
        beth.deposit{ value: a3 }();
        expectedBalance[user] += a3;
        expectedTotalSupply += a3;
        expectedTotalBurned += a3;

        assertEq(beth.balanceOf(user), expectedBalance[user]);
        assertEq(beth.totalSupply(), expectedTotalSupply);
        assertEq(beth.totalBurned(), expectedTotalBurned);
        assertEq(address(beth).balance, 0);
    }
}
