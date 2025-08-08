// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import { BETH } from "src/BETH.sol";

contract DepositToScript is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address payable bethAddr = payable(vm.envAddress("BETH_ADDRESS"));
        uint256 amount = vm.envUint("DEPOSIT_AMOUNT_WEI");
        address recipient = vm.envAddress("RECIPIENT");

        vm.startBroadcast(pk);
        BETH(bethAddr).depositTo{ value: amount }(recipient);
        vm.stopBroadcast();

        console2.log("Deposited", amount, "wei to", bethAddr);
    }
}
