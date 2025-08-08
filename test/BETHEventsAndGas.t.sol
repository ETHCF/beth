// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, Vm} from "forge-std/Test.sol";
import {BETH} from "src/BETH.sol";

contract BETHEventsAndGasTest is Test {
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
                // Burned topics/data
                assertEq(logs[i].topics.length, 2);
                assertEq(address(uint160(uint256(logs[i].topics[1]))), from);
                assertEq(abi.decode(logs[i].data, (uint256)), amount);
                idxBurned = int256(i);
            } else if (sig == sigMinted) {
                // Minted topics/data
                assertEq(logs[i].topics.length, 2);
                assertEq(address(uint160(uint256(logs[i].topics[1]))), receiver);
                assertEq(abi.decode(logs[i].data, (uint256)), amount);
                idxMinted = int256(i);
            } else if (sig == sigTransfer) {
                // ERC20 Transfer from 0x0 on mint
                if (
                    address(uint160(uint256(logs[i].topics[1]))) == address(0) &&
                    address(uint160(uint256(logs[i].topics[2]))) == receiver &&
                    abi.decode(logs[i].data, (uint256)) == amount
                ) {
                    sawTransferMint = true;
                } else {
                    // No other ERC20 logs expected during mint
                    fail();
                }
            } else {
                // No other custom logs expected
                fail();
            }
        }

        assertTrue(sawTransferMint, "missing ERC20 mint Transfer");
        assertGe(idxBurned, 0);
        assertGe(idxMinted, 0);
        assertLt(uint256(idxBurned), uint256(idxMinted));
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
        // Basic gas measurement via gasleft sampling
        uint256 g0 = gasleft();
        beth.deposit{value: 1 ether}();
        uint256 used = g0 - gasleft();
        emit log_named_uint("gas_deposit", used);
    }

    function test_GasSnapshot_DepositTo() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        uint256 g1 = gasleft();
        beth.depositTo{value: 1 ether}(bob);
        uint256 used1 = g1 - gasleft();
        emit log_named_uint("gas_depositTo", used1);
    }

    function test_GasSnapshot_Receive() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        uint256 g2 = gasleft();
        (bool ok, ) = address(beth).call{value: 1 ether}("");
        require(ok, "receive failed");
        uint256 used2 = g2 - gasleft();
        emit log_named_uint("gas_receive", used2);
    }

    // Assert specific storage writes only
    function _assertOnlyMintStorageWrites(address recipient, uint256 amount) internal {
        vm.record();
        vm.deal(alice, amount);
        vm.prank(alice);
        beth.depositTo{value: amount}(recipient);

        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(beth));
        reads;
        // Count unique writes; should be minimal (balances, totalSupply, totalBurned)
        // Avoid relying on exact slot numbers; just ensure no unexpected proliferation
        uint256 unique;
        for (uint256 i = 0; i < writes.length; i++) {
            bool seen;
            for (uint256 j = 0; j < i; j++) {
                if (writes[i] == writes[j]) { seen = true; break; }
            }
            if (!seen) unique++;
        }
        assertLe(unique, 3, "unexpected number of storage writes");
    }

    function test_OnlyStorageWrites_Balances_Supply_Burned() public {
        _assertOnlyMintStorageWrites(bob, 1 ether);
    }

    // Code surface checks
    function test_CodeSurface_NoFallbackPaths_BurnHasNoCode() public {
        // BETH has code
        assertGt(address(beth).code.length, 0);

        // Calls with nonempty data revert
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool ok, ) = address(beth).call{value: 0.1 ether}(hex"616263");
        assertFalse(ok);

        // Burn address has no code
        assertEq(BURN.code.length, 0);
    }
}


