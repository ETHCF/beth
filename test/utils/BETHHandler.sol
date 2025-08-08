// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { BETH } from "src/BETH.sol";

contract BETHHandler is StdCheats, StdUtils {
    BETH public immutable beth;

    constructor(BETH _beth) {
        beth = _beth;
    }

    function deposit(uint128 amount) public {
        amount = uint128(bound(uint256(amount), 1, 1000 ether));
        deal(address(this), amount);
        beth.deposit{ value: amount }();
    }

    function depositTo(address recipient, uint128 amount) public {
        if (recipient == address(0)) recipient = address(1);
        amount = uint128(bound(uint256(amount), 1, 1000 ether));
        deal(address(this), amount);
        beth.depositTo{ value: amount }(recipient);
    }
}
