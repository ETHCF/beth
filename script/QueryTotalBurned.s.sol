// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {BETH} from "src/BETH.sol";

contract QueryTotalBurned is Script {
    function run() external view {
        address bethAddr = vm.envAddress("BETH_ADDRESS");
        uint256 burned = BETH(bethAddr).totalBurned();
        console2.log("totalBurned:", burned);
    }
}
