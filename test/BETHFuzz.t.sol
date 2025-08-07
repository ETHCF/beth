// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BETH} from "src/BETH.sol";

contract BETHFuzzTest is Test {
    BETH internal beth;
    address internal constant BURN = address(0x000000000000000000000000000000000000dEaD);

    function setUp() public {
        beth = new BETH();
    }

    function testFuzz_Deposit(address user, uint128 amount) public {
        vm.assume(user != address(0) && user != BURN);
        amount = uint128(bound(uint256(amount), 1, 1_000_000 ether));
        vm.deal(user, amount);

        uint256 burnBefore = BURN.balance;
        vm.prank(user);
        beth.deposit{value: amount}();

        assertEq(beth.balanceOf(user), amount);
        assertEq(beth.totalBurned(), amount);
        assertEq(address(beth).balance, 0);
        assertEq(BURN.balance, burnBefore + amount);
    }

    function testFuzz_DepositTo(address user, address recipient, uint128 amount) public {
        vm.assume(user != address(0) && user != BURN);
        vm.assume(recipient != address(0));
        amount = uint128(bound(uint256(amount), 1, 1_000_000 ether));
        vm.deal(user, amount);

        uint256 burnBefore = BURN.balance;
        vm.prank(user);
        beth.depositTo{value: amount}(recipient);

        assertEq(beth.balanceOf(recipient), amount);
        assertEq(beth.totalBurned(), amount);
        assertEq(address(beth).balance, 0);
        assertEq(BURN.balance, burnBefore + amount);
    }
}
