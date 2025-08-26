// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, Vm } from "forge-std/Test.sol";
import { BETH } from "src/BETH.sol";

contract BETHUnit is Test {
    BETH internal beth;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal constant BURN = address(0x0000000000000000000000000000000000000000);

    event Burned(address indexed from, uint256 amount);
    event Minted(address indexed to, uint256 amount);

    function setUp() public {
        beth = new BETH();
    }

    function test_Decimals_18() public {
        assertEq(beth.decimals(), 18);
    }

    function test_Deposit_EventsAndAccounting() public {
        vm.deal(alice, 1 ether);

        uint256 burnBefore = BURN.balance;
        vm.expectEmit(true, true, true, true, address(beth));
        emit Burned(alice, 1 ether);
        vm.expectEmit(true, true, true, true, address(beth));
        emit Minted(alice, 1 ether);

        vm.prank(alice);
        beth.deposit{ value: 1 ether }();

        assertEq(beth.balanceOf(alice), 1 ether);
        assertEq(beth.totalSupply(), 1 ether);
        assertEq(beth.totalBurned(), 1 ether);
        assertEq(BURN.balance, burnBefore + 1 ether);
        assertEq(address(beth).balance, 0);
    }

    function test_DepositTo_Basic() public {
        vm.deal(alice, 2 ether);
        vm.prank(alice);
        beth.depositTo{ value: 2 ether }(bob);
        assertEq(beth.balanceOf(bob), 2 ether);
        assertEq(beth.totalSupply(), 2 ether);
        assertEq(beth.totalBurned(), 2 ether);
        assertEq(address(beth).balance, 0);
    }

    function test_DepositTo_ZeroAddress_Reverts() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert();
        beth.depositTo{ value: 1 ether }(address(0));
    }

    function test_ERC20_Transfer_Approve_TransferFrom() public {
        vm.deal(alice, 3 ether);
        vm.prank(alice);
        beth.deposit{ value: 3 ether }();

        // transfer
        vm.prank(alice);
        bool ok = beth.transfer(bob, 1 ether);
        assertTrue(ok);
        assertEq(beth.balanceOf(alice), 2 ether);
        assertEq(beth.balanceOf(bob), 1 ether);

        // approve + transferFrom
        vm.prank(alice);
        ok = beth.approve(bob, 1.5 ether);
        assertTrue(ok);
        vm.prank(bob);
        ok = beth.transferFrom(alice, bob, 1.5 ether);
        assertTrue(ok);
        assertEq(beth.balanceOf(alice), 0.5 ether);
        assertEq(beth.balanceOf(bob), 2.5 ether);
    }

    // Event ordering: Burned then Minted; any extra log must be ERC20 Transfer mint
    function test_EventOrdering_DepositAndDepositTo() public {
        _assertEventOrder(alice, address(0), 0.3 ether);
        _assertEventOrder(alice, bob, 0.4 ether);
    }

    function _assertEventOrder(address from, address to, uint256 amount) internal {
        vm.deal(from, amount);
        vm.recordLogs();
        if (to == address(0)) {
            vm.prank(from);
            beth.deposit{ value: amount }();
        } else {
            vm.prank(from);
            beth.depositTo{ value: amount }(to);
        }
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 sigBurned = keccak256("Burned(address,uint256)");
        bytes32 sigMinted = keccak256("Minted(address,uint256)");
        bytes32 sigTransfer = keccak256("Transfer(address,address,uint256)");

        address receiver = to == address(0) ? from : to;
        int256 idxBurned = -1;
        int256 idxMinted = -1;
        bool sawTransferMint;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter != address(beth)) continue;
            bytes32 sig = logs[i].topics[0];
            if (sig == sigBurned) {
                idxBurned = int256(i);
                assertEq(address(uint160(uint256(logs[i].topics[1]))), from);
                assertEq(abi.decode(logs[i].data, (uint256)), amount);
            } else if (sig == sigMinted) {
                idxMinted = int256(i);
                assertEq(address(uint160(uint256(logs[i].topics[1]))), receiver);
                assertEq(abi.decode(logs[i].data, (uint256)), amount);
            } else if (sig == sigTransfer) {
                if (
                    address(uint160(uint256(logs[i].topics[1]))) == address(0)
                        && address(uint160(uint256(logs[i].topics[2]))) == receiver
                        && abi.decode(logs[i].data, (uint256)) == amount
                ) {
                    sawTransferMint = true;
                } else {
                    fail();
                }
            } else {
                fail();
            }
        }
        assertTrue(sawTransferMint);
        assertGe(idxBurned, 0);
        assertGe(idxMinted, 0);
        assertLt(uint256(idxBurned), uint256(idxMinted));
    }
}
