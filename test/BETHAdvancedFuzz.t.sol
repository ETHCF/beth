// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BETH} from "src/BETH.sol";

contract BETHAdvancedFuzzTest is Test {
    BETH internal beth;

    // Running expectations across fuzz iterations in this test contract
    mapping(address => uint256) internal expectedBalance;
    uint256 internal expectedTotalSupply;
    uint256 internal expectedTotalBurned;

    event Burned(address indexed from, uint256 amount);
    event Minted(address indexed to, uint256 amount);

    function setUp() public {
        beth = new BETH();
    }


    function testFuzz_Deposit_RunningSums(address sender, uint96 amount) public {
        vm.assume(sender != address(0));
        vm.assume(amount > 0);

        vm.deal(sender, amount);

        vm.prank(sender);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Burned(sender, amount);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Minted(sender, amount);
        beth.deposit{value: amount}();

        expectedBalance[sender] += amount;
        expectedTotalSupply += amount;
        expectedTotalBurned += amount;

        assertEq(beth.balanceOf(sender), expectedBalance[sender]);
        assertEq(beth.totalSupply(), expectedTotalSupply);
        assertEq(beth.totalBurned(), expectedTotalBurned);
        assertEq(address(beth).balance, 0);
    }

    function testFuzz_DepositTo_Invariants(address sender, address recipient, uint96 amount) public {
        vm.assume(sender != address(0));
        vm.assume(recipient != address(0));
        vm.assume(amount > 0);

        vm.deal(sender, amount);

        vm.prank(sender);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Burned(sender, amount);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Minted(recipient, amount);
        beth.depositTo{value: amount}(recipient);

        // ERC20 invariants
        assertEq(beth.balanceOf(recipient), expectedBalance[recipient] + amount);
        expectedBalance[recipient] += amount;
        expectedTotalSupply += amount;
        expectedTotalBurned += amount;
        assertEq(beth.totalSupply(), expectedTotalSupply);
        assertEq(beth.totalBurned(), expectedTotalBurned);
        assertEq(address(beth).balance, 0);
    }

    function testFuzz_InterleavedOps(
        address a,
        address b,
        uint96 depA,
        uint96 depB,
        uint96 approveAmt,
        uint96 xferAmt
    ) public {
        vm.assume(a != address(0));
        vm.assume(b != address(0));

        // Deposits
        if (depA > 0) {
            vm.deal(a, depA);
            vm.prank(a);
            beth.deposit{value: depA}();
            expectedBalance[a] += depA;
            expectedTotalSupply += depA;
            expectedTotalBurned += depA;
        }
        if (depB > 0) {
            vm.deal(b, depB);
            vm.prank(b);
            beth.deposit{value: depB}();
            expectedBalance[b] += depB;
            expectedTotalSupply += depB;
            expectedTotalBurned += depB;
        }

        // approve a->b
        if (approveAmt > 0) {
            vm.prank(a);
            beth.approve(b, approveAmt);
            assertEq(beth.allowance(a, b), approveAmt);
        }

        // transfer a->b
        if (xferAmt > 0) {
            uint256 send = xferAmt;
            if (send > expectedBalance[a]) send = expectedBalance[a];
            vm.prank(a);
            beth.transfer(b, send);
            expectedBalance[a] -= send;
            expectedBalance[b] += send;
        }

        // transferFrom a->b by b
        if (approveAmt > 0) {
            uint256 send2 = approveAmt;
            if (send2 > expectedBalance[a]) send2 = expectedBalance[a];
            vm.prank(b);
            beth.transferFrom(a, b, send2);
            expectedBalance[a] -= send2;
            expectedBalance[b] += send2;
        }

        // Invariant: totalSupply == totalBurned always; balances track
        assertEq(beth.totalSupply(), expectedTotalSupply);
        assertEq(beth.totalBurned(), expectedTotalBurned);
        assertEq(beth.balanceOf(a), expectedBalance[a]);
        assertEq(beth.balanceOf(b), expectedBalance[b]);
        assertEq(address(beth).balance, 0);
    }
}


