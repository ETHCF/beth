// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { BETH } from "src/BETH.sol";
import { BETHReentryHarness } from "test/utils/BETHReentryHarness.sol";

contract FakeFail {
    receive() external payable {
        revert("fail");
    }
}

contract BurnForwardingUnit is Test {
    address internal constant BURN = address(0x000000000000000000000000000000000000dEaD);

    function testFuzz_BurnEOA_CallWithEmptyData_Succeeds(uint128 amount) public {
        vm.assume(amount > 0);
        // Ensure burn has no code
        assertEq(BURN.code.length, 0);
        // Fund this contract and attempt raw call with empty data
        deal(address(this), amount);
        (bool ok,) = payable(BURN).call{ value: amount }("");
        assertTrue(ok);
    }

    function testFuzz_Deposit_ForwardsToBurn_Succeeds(uint128 amount) public {
        vm.assume(amount > 0);
        assertEq(BURN.code.length, 0);
        BETH beth = new BETH();
        address alice = address(0xA11CE);
        deal(alice, amount);
        vm.prank(alice);
        beth.deposit{ value: amount }();
        assertEq(beth.balanceOf(alice), amount);
        assertEq(beth.totalSupply(), amount);
        assertEq(beth.totalBurned(), amount);
    }

    function test_Deposit_Reverts_WhenForwardFails_Artificial() public {
        // Harness that allows swapping the forward target
        BETHReentryHarness h = new BETHReentryHarness(address(0xdead));
        FakeFail sink = new FakeFail();
        h.setForwardTarget(address(sink));

        address user = address(0xBEEF);
        deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert(BETH.ForwardFailed.selector);
        h.deposit{ value: 1 ether }();
    }
}
