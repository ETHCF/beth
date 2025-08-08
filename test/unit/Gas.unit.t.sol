// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { BETH } from "src/BETH.sol";

contract GasUnit is Test {
    BETH internal beth;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    // Thresholds are conservative upper-bounds to catch regressions while tolerating minor variance
    // Current measured ~127k; set headroom but detect regressions
    uint256 internal constant GAS_DEPOSIT_MAX = 140_000;
    uint256 internal constant GAS_DEPOSIT_TO_MAX = 145_000;
    uint256 internal constant GAS_RECEIVE_MAX = 140_000;

    function setUp() public {
        beth = new BETH();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_Gas_Deposit_UnderThreshold() public {
        vm.prank(alice);
        uint256 g0 = gasleft();
        beth.deposit{ value: 1 ether }();
        uint256 used = g0 - gasleft();
        emit log_named_uint("gas_deposit", used);
        assertLe(used, GAS_DEPOSIT_MAX, "deposit gas exceeded threshold");
    }

    function test_Gas_DepositTo_UnderThreshold() public {
        vm.prank(alice);
        uint256 g0 = gasleft();
        beth.depositTo{ value: 1 ether }(bob);
        uint256 used = g0 - gasleft();
        emit log_named_uint("gas_depositTo", used);
        assertLe(used, GAS_DEPOSIT_TO_MAX, "depositTo gas exceeded threshold");
    }

    function test_Gas_Receive_UnderThreshold() public {
        vm.prank(alice);
        uint256 g0 = gasleft();
        (bool ok,) = address(beth).call{ value: 1 ether }("");
        require(ok, "receive failed");
        uint256 used = g0 - gasleft();
        emit log_named_uint("gas_receive", used);
        assertLe(used, GAS_RECEIVE_MAX, "receive gas exceeded threshold");
    }
}
