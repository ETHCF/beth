// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BETH} from "src/BETH.sol";

contract SelfDestructPusher {
    constructor() payable {}

    function boom(address payable target) external {
        selfdestruct(target);
    }
}

contract ForcedEtherTest is Test {
    BETH internal beth;

    function setUp() public {
        beth = new BETH();
    }

    function test_ForcedEtherThenFlush() public {
        // Arrange: fund a helper that will force ETH into the BETH contract
        SelfDestructPusher pusher = new SelfDestructPusher{value: 1 ether}();

        // Act: force-send ETH via selfdestruct; no function on BETH is invoked
        pusher.boom(payable(address(beth)));

        // Sanity: ETH is now stuck on the contract
        assertEq(address(beth).balance, 1 ether);

        // Anyone can flush it to the burn address, increasing totalBurned without minting
        uint256 burnedBefore = beth.totalBurned();
        beth.flush();
        assertEq(address(beth).balance, 0);
        assertEq(beth.totalBurned(), burnedBefore + 1 ether);
    }
}


