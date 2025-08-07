// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BETH} from "src/BETH.sol";
import {BETHHandler} from "test/utils/BETHHandler.sol";

contract BETHInvariantTest is Test {
    BETH internal beth;
    BETHHandler internal handler;

    function setUp() public {
        beth = new BETH();
        handler = new BETHHandler(beth);
        targetContract(address(handler));
    }

    function invariant_NoETHRetention() public view {
        assertEq(address(beth).balance, 0);
    }

    function invariant_TotalSupplyEqualsTotalBurned() public view {
        assertEq(beth.totalSupply(), beth.totalBurned());
    }
}
