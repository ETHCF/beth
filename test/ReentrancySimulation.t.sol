// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { BETHReentryHarness } from "test/utils/BETHReentryHarness.sol";

contract FakeBurn {
    BETHReentryHarness public beth;
    address public recipient;
    bool internal entered;

    constructor(BETHReentryHarness _beth, address _recipient) payable {
        beth = _beth;
        recipient = _recipient;
    }

    receive() external payable {
        if (entered) return; // single reentry attempt
        entered = true;
        // Attempt to find a callback into BETH; none exists besides receive/deposit paths.
        // Try calling a supposed hook; this will revert.
        (bool ok,) = address(beth).call(abi.encodeWithSignature("onForwardCallback()"));
        // Expect the callback to fail and not affect state
        assert(!ok);
        // Try reentering depositTo using the ether we just received (should require sending ETH back)
        // This contract has no remaining balance to forward (funds came from BETH), so this is a noop.
    }
}

contract ReentrancySimulation is Test {
    BETHReentryHarness internal beth;
    address internal alice = address(0xA11CE);

    function setUp() public {
        // Forward target will be replaced by a fake burn contract that tries reentrancy
        beth = new BETHReentryHarness(address(0xdead));
    }

    function test_ReentrancyImpossible_NoCallbackPath() public {
        vm.deal(alice, 1 ether);
        FakeBurn fb = new FakeBurn(beth, alice);
        beth.setForwardTarget(address(fb));

        uint256 supplyBefore = beth.totalSupply();
        vm.prank(alice);
        beth.deposit{ value: 0.4 ether }();

        // Mint occurred as usual
        assertEq(beth.balanceOf(alice), 0.4 ether);
        assertEq(beth.totalBurned(), supplyBefore + 0.4 ether);
        // No extra mints to any third party and no state corruption
        assertEq(address(beth).balance, 0);
    }
}
