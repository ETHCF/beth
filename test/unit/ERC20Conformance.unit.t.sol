// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { BETH } from "src/BETH.sol";
import { IERC20Errors } from "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";

contract ERC20Conformance is Test {
    BETH internal beth;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal spender = address(0x5);
    address internal constant BURN = address(0x000000000000000000000000000000000000dEaD);

    function setUp() public {
        beth = new BETH();
    }

    function test_Decimals_Is18() public {
        assertEq(beth.decimals(), 18);
    }

    function test_Transfer_StandardBehavior() public {
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        beth.deposit{ value: 5 ether }();

        uint256 aliceBefore = beth.balanceOf(alice);
        uint256 bobBefore = beth.balanceOf(bob);
        vm.prank(alice);
        bool ok = beth.transfer(bob, 2 ether);
        assertTrue(ok);
        assertEq(beth.balanceOf(alice), aliceBefore - 2 ether);
        assertEq(beth.balanceOf(bob), bobBefore + 2 ether);

        vm.prank(alice);
        vm.expectRevert();
        beth.transfer(bob, type(uint256).max);
    }

    function test_Transfer_Revert_ZeroAddress() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        beth.deposit{ value: 1 ether }();

        vm.prank(alice);
        vm.expectRevert();
        beth.transfer(address(0), 1);
    }

    function test_TransferFrom_InsufficientAllowance_Reverts_NoChange() public {
        vm.deal(alice, 3 ether);
        vm.prank(alice);
        beth.deposit{ value: 3 ether }();

        vm.prank(alice);
        beth.approve(spender, 1 ether);
        assertEq(beth.allowance(alice, spender), 1 ether);

        vm.prank(spender);
        vm.expectRevert();
        beth.transferFrom(alice, bob, 2 ether);

        assertEq(beth.allowance(alice, spender), 1 ether);
        assertEq(beth.balanceOf(alice), 3 ether);
        assertEq(beth.balanceOf(bob), 0);
    }

    function test_Approve_And_TransferFrom_AllowanceMath() public {
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        beth.deposit{ value: 5 ether }();

        vm.prank(alice);
        bool ok = beth.approve(spender, 3 ether);
        assertTrue(ok);
        assertEq(beth.allowance(alice, spender), 3 ether);

        vm.prank(spender);
        ok = beth.transferFrom(alice, bob, 2 ether);
        assertTrue(ok);
        assertEq(beth.allowance(alice, spender), 1 ether);
        assertEq(beth.balanceOf(bob), 2 ether);

        vm.prank(spender);
        ok = beth.transferFrom(alice, bob, 1 ether);
        assertTrue(ok);
        assertEq(beth.allowance(alice, spender), 0);
        assertEq(beth.balanceOf(bob), 3 ether);
    }

    function test_TransferFrom_InfiniteApproval_DoesNotDecreaseAllowance() public {
        vm.deal(alice, 7 ether);
        vm.prank(alice);
        beth.deposit{ value: 7 ether }();

        vm.prank(alice);
        beth.approve(spender, type(uint256).max);
        assertEq(beth.allowance(alice, spender), type(uint256).max);

        vm.prank(spender);
        beth.transferFrom(alice, bob, 4 ether);
        assertEq(beth.allowance(alice, spender), type(uint256).max);
        assertEq(beth.balanceOf(bob), 4 ether);
    }

    function test_Approve_RacePattern_OZSpec() public {
        vm.deal(alice, 2 ether);
        vm.prank(alice);
        beth.deposit{ value: 2 ether }();

        vm.prank(alice);
        beth.approve(spender, 1 ether);
        assertEq(beth.allowance(alice, spender), 1 ether);

        vm.prank(alice);
        beth.approve(spender, 0);
        assertEq(beth.allowance(alice, spender), 0);
        vm.prank(alice);
        beth.approve(spender, 2 ether);
        assertEq(beth.allowance(alice, spender), 2 ether);

        vm.prank(alice);
        beth.approve(spender, 3 ether);
        assertEq(beth.allowance(alice, spender), 3 ether);
    }
}
