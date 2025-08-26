// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { BETH } from "src/BETH.sol";

contract BETHBytecodeHash is Test {
    // Update when intentionally changing compiler/OZ/contract logic.
    // The hash is keccak256 of runtime code (extcodehash).
    bytes32 internal constant EXPECTED_RUNTIME_CODE_HASH =
        hex"ec7b43423f3613d30d52451076f64b966f928c550edd267dcaa377d804fa7f9e";

    function test_RuntimeCodeHash_MatchesExpected() public {
        BETH beth = new BETH();
        bytes32 codehash;
        assembly {
            codehash := extcodehash(beth)
        }
        assertEq(
            codehash,
            EXPECTED_RUNTIME_CODE_HASH,
            "Runtime code hash mismatch; run make update-golden"
        );
    }
}
