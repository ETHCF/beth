// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GasSnapshot} from "forge-std/GasSnapshot.sol";
import {BETH} from "src/BETH.sol";

contract BETHEventsAndGasTest is Test, GasSnapshot {
    BETH internal beth;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal constant BURN = address(0x000000000000000000000000000000000000dEaD);

    event Burned(address indexed from, uint256 amount);
    event Minted(address indexed to, uint256 amount);

    function setUp() public {
        beth = new BETH();
    }

    function _assertEventOrderAndTopics(address from, address to, uint256 amount) internal {
        vm.recordLogs();
        if (from == to) revert("invalid test params");

        // Perform deposit path depending on presence of to
        if (to == address(0)) {
            vm.prank(from);
            beth.deposit{value: amount}();
        } else {
            vm.prank(from);
            beth.depositTo{value: amount}(to);
        }

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 3, "exactly Burned, Minted, Transfer should be emitted");

        bytes32 sigBurned = keccak256("Burned(address,uint256)");
        bytes32 sigMinted = keccak256("Minted(address,uint256)");
        bytes32 sigTransfer = keccak256("Transfer(address,address,uint256)");

        // Burned first
        assertEq(logs[0].emitter, address(beth));
        assertEq(logs[0].topics.length, 2);
        assertEq(logs[0].topics[0], sigBurned);
        assertEq(address(uint160(uint256(logs[0].topics[1]))), from);
        assertEq(abi.decode(logs[0].data, (uint256)), amount);

        // Minted second
        address receiver = to == address(0) ? from : to;
        assertEq(logs[1].emitter, address(beth));
        assertEq(logs[1].topics.length, 2);
        assertEq(logs[1].topics[0], sigMinted);
        assertEq(address(uint160(uint256(logs[1].topics[1]))), receiver);
        assertEq(abi.decode(logs[1].data, (uint256)), amount);

        // Transfer third (mint)
        assertEq(logs[2].emitter, address(beth));
        assertEq(logs[2].topics.length, 3);
        assertEq(logs[2].topics[0], sigTransfer);
        assertEq(address(uint160(uint256(logs[2].topics[1]))), address(0));
        assertEq(address(uint160(uint256(logs[2].topics[2]))), receiver);
        assertEq(abi.decode(logs[2].data, (uint256)), amount);
    }

    function test_EventOrdering_Deposit() public {
        vm.deal(alice, 1 ether);
        _assertEventOrderAndTopics(alice, address(0), 1 ether);
    }

    function test_EventOrdering_DepositTo() public {
        vm.deal(alice, 2 ether);
        _assertEventOrderAndTopics(alice, bob, 2 ether);
    }

    // Gas snapshots
    function test_GasSnapshot_Deposit() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        snapshotStart("deposit");
        beth.deposit{value: 1 ether}();
        snapshotEnd();
    }

    function test_GasSnapshot_DepositTo() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        snapshotStart("depositTo");
        beth.depositTo{value: 1 ether}(bob);
        snapshotEnd();
    }

    function test_GasSnapshot_Receive() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        snapshotStart("receive");
        (bool ok, ) = address(beth).call{value: 1 ether}("");
        require(ok, "receive failed");
        snapshotEnd();
    }

    // Assert specific storage writes only
    function _assertOnlyMintStorageWrites(address recipient, uint256 amount) internal {
        // compute mapping slot for balances[recipient] at OZ slot 0
        bytes32 balanceSlot = keccak256(abi.encode(recipient, uint256(0)));
        bytes32 totalSupplySlot = bytes32(uint256(2));
        bytes32 totalBurnedSlot = bytes32(uint256(3));

        vm.record();
        vm.deal(alice, amount);
        vm.prank(alice);
        beth.depositTo{value: amount}(recipient);

        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(beth));
        reads;
        bool sawBalance;
        bool sawSupply;
        bool sawBurned;
        bool sawOther;
        for (uint256 i = 0; i < writes.length; i++) {
            bytes32 w = writes[i];
            if (w == balanceSlot) sawBalance = true;
            else if (w == totalSupplySlot) sawSupply = true;
            else if (w == totalBurnedSlot) sawBurned = true;
            else sawOther = true;
        }
        assertTrue(sawBalance && sawSupply && sawBurned, "missing expected writes");
        assertFalse(sawOther, "unexpected storage writes");
    }

    function test_OnlyStorageWrites_Balances_Supply_Burned() public {
        _assertOnlyMintStorageWrites(bob, 1 ether);
    }

    // Code surface checks
    function test_CodeSurface_NoFallbackPaths_BurnHasNoCode() public {
        // extcodesize(BETH) > 0
        uint256 size;
        assembly {
            size := extcodesize(sload(beth.slot))
        }
        assertGt(size, 0);

        // Calls with nonempty data revert
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool ok, ) = address(beth).call{value: 0.1 ether}(hex"616263");
        assertFalse(ok);

        // Burn address has no code
        uint256 burnSize;
        assembly {
            burnSize := extcodesize(BURN)
        }
        assertEq(burnSize, 0);
    }
}


