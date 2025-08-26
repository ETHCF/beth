// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, Vm } from "forge-std/Test.sol";
import { BETH } from "src/BETH.sol";

contract EventAccounting is Test {
    BETH internal beth;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal constant BURN = address(0x0000000000000000000000000000000000000000);

    bytes32 internal constant SIG_BURNED = keccak256("Burned(address,uint256)");
    bytes32 internal constant SIG_MINTED = keccak256("Minted(address,uint256)");

    function setUp() public {
        beth = new BETH();
    }

    function _sumBurnedMinted(Vm.Log[] memory logs)
        internal
        pure
        returns (uint256 burned, uint256 minted)
    {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length == 0) continue;
            bytes32 sig = logs[i].topics[0];
            if (sig == SIG_BURNED) {
                burned += abi.decode(logs[i].data, (uint256));
            } else if (sig == SIG_MINTED) {
                minted += abi.decode(logs[i].data, (uint256));
            }
        }
    }

    function _assertTotalsMatchEventDeltas(
        uint256 ts0,
        uint256 tb0,
        uint256 burnedDelta,
        uint256 mintedDelta
    ) internal view {
        assertEq(mintedDelta, burnedDelta, "minted != burned deltas");
        assertEq(beth.totalSupply(), ts0 + mintedDelta, "totalSupply mismatch vs events");
        assertEq(beth.totalBurned(), tb0 + burnedDelta, "totalBurned mismatch vs events");
    }

    function testFuzz_EventsAccounting_SingleOperation(
        uint8 op,
        address sender,
        address recipient,
        uint96 amount
    ) public {
        vm.assume(sender != address(0) && sender != BURN);
        vm.assume(recipient != address(0) && recipient != BURN);
        vm.assume(amount > 0);

        uint256 ts0 = beth.totalSupply();
        uint256 tb0 = beth.totalBurned();

        vm.recordLogs();

        if (op % 3 == 0) {
            // deposit
            vm.deal(sender, amount);
            vm.prank(sender);
            beth.deposit{ value: amount }();
        } else if (op % 3 == 1) {
            // depositTo
            vm.deal(sender, amount);
            vm.prank(sender);
            beth.depositTo{ value: amount }(recipient);
        } else {
            // receive
            vm.deal(sender, amount);
            vm.prank(sender);
            (bool ok,) = address(beth).call{ value: amount }("");
            assertTrue(ok, "receive failed");
        }

        Vm.Log[] memory logs = vm.getRecordedLogs();
        (uint256 burnedDelta, uint256 mintedDelta) = _sumBurnedMinted(logs);
        _assertTotalsMatchEventDeltas(ts0, tb0, burnedDelta, mintedDelta);
    }

    function testFuzz_EventsAccounting_ThreeStep(
        address s1,
        address s2,
        address s3,
        address r1,
        address r2,
        uint96 a1,
        uint96 a2,
        uint96 a3,
        uint8 op1,
        uint8 op2,
        uint8 op3
    ) public {
        vm.assume(s1 != address(0) && s2 != address(0) && s3 != address(0));
        vm.assume(r1 != address(0) && r2 != address(0));
        vm.assume(s1 != BURN && s2 != BURN && s3 != BURN);
        vm.assume(r1 != BURN && r2 != BURN);

        uint256 ts0 = beth.totalSupply();
        uint256 tb0 = beth.totalBurned();

        vm.recordLogs();

        _doOp(op1, s1, r1, a1);
        _doOp(op2, s2, r2, a2);
        _doOp(op3, s3, r1, a3);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        (uint256 burnedDelta, uint256 mintedDelta) = _sumBurnedMinted(logs);
        _assertTotalsMatchEventDeltas(ts0, tb0, burnedDelta, mintedDelta);
    }

    function _doOp(uint8 op, address sender, address recipient, uint96 amount) internal {
        if (amount == 0) return;
        if (op % 3 == 0) {
            vm.deal(sender, amount);
            vm.prank(sender);
            beth.deposit{ value: amount }();
        } else if (op % 3 == 1) {
            vm.deal(sender, amount);
            vm.prank(sender);
            beth.depositTo{ value: amount }(recipient);
        } else {
            vm.deal(sender, amount);
            vm.prank(sender);
            (bool ok,) = address(beth).call{ value: amount }("");
            require(ok, "receive failed");
        }
    }
}
