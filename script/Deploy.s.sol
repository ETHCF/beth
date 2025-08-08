// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import { BETH } from "src/BETH.sol";

contract DeployBETH is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        BETH beth = new BETH();
        vm.stopBroadcast();
        console2.log("BETH:", address(beth));
    }
}
