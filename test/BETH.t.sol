// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {BETH} from "src/BETH.sol";

contract BETHTest is Test {
    BETH internal beth;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal constant BURN = address(0x000000000000000000000000000000000000dEaD);

    function setUp() public {
        beth = new BETH();
    }

    function test_DecimalsIs18() public {
        assertEq(beth.decimals(), 18);
    }

    function test_Deposit_MintsAndForwards() public {
        vm.deal(alice, 10 ether);
        uint256 burnBefore = BURN.balance;

        vm.prank(alice);
        uint256 minted = beth.deposit{value: 1 ether}();

        assertEq(minted, 1 ether);
        assertEq(beth.balanceOf(alice), 1 ether);
        assertEq(beth.totalBurned(), 1 ether);
        assertEq(address(beth).balance, 0);
        assertEq(BURN.balance, burnBefore + 1 ether);
    }

    function test_DepositTo_MintsToRecipientAndForwards() public {
        vm.deal(alice, 10 ether);
        uint256 burnBefore = BURN.balance;

        vm.prank(alice);
        uint256 minted = beth.depositTo{value: 2 ether}(bob);

        assertEq(minted, 2 ether);
        assertEq(beth.balanceOf(bob), 2 ether);
        assertEq(beth.totalBurned(), 2 ether);
        assertEq(address(beth).balance, 0);
        assertEq(BURN.balance, burnBefore + 2 ether);
    }

    function test_Receive_MintsToSender() public {
        vm.deal(alice, 5 ether);
        uint256 burnBefore = BURN.balance;

        vm.prank(alice);
        (bool ok, ) = payable(address(beth)).call{value: 3 ether}("");
        assertTrue(ok);

        assertEq(beth.balanceOf(alice), 3 ether);
        assertEq(beth.totalBurned(), 3 ether);
        assertEq(address(beth).balance, 0);
        assertEq(BURN.balance, burnBefore + 3 ether);
    }

    function test_RevertOnZeroDeposit_Deposit() public {
        vm.expectRevert(BETH.ZeroDeposit.selector);
        beth.deposit{value: 0}();
    }

    function test_RevertOnZeroDeposit_DepositTo() public {
        vm.expectRevert(BETH.ZeroDeposit.selector);
        beth.depositTo{value: 0}(bob);
    }

    function test_ERC20_Transfer() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        beth.deposit{value: 1 ether}();

        vm.prank(alice);
        bool success = beth.transfer(bob, 0.4 ether);
        assertTrue(success);
        assertEq(beth.balanceOf(alice), 0.6 ether);
        assertEq(beth.balanceOf(bob), 0.4 ether);
    }

    function test_ERC20_ApproveAndTransferFrom() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        beth.deposit{value: 1 ether}();

        vm.prank(alice);
        beth.approve(bob, 0.5 ether);
        assertEq(beth.allowance(alice, bob), 0.5 ether);

        vm.prank(bob);
        bool success = beth.transferFrom(alice, bob, 0.5 ether);
        assertTrue(success);
        assertEq(beth.balanceOf(alice), 0.5 ether);
        assertEq(beth.balanceOf(bob), 0.5 ether);
    }
}
