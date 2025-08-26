// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

contract BETHAbiHash is Test {
    function test_ABI_KeccakMatchesCommittedSnapshot() public {
        // Read committed ABI
        string memory path = string.concat(vm.projectRoot(), "/abi/BETH.json");
        // Canonicalize committed ABI with jq -c (minify & stable key order)
        string[] memory jqFile = new string[](4);
        jqFile[0] = "bash";
        jqFile[1] = "-lc";
        jqFile[2] = string.concat("jq -c '.' ", path);
        // placeholder for index 3 unused
        bytes memory committed = vm.ffi(jqFile);
        bytes32 committedHash = keccak256(committed);

        // Generate current ABI via forge inspect
        string[] memory cmds = new string[](4);
        cmds[0] = "forge";
        cmds[1] = "inspect";
        cmds[2] = "src/BETH.sol:BETH";
        cmds[3] = "abi";
        // Pipe through jq -c for canonicalization
        string[] memory pipe = new string[](4);
        pipe[0] = "bash";
        pipe[1] = "-lc";
        pipe[2] = "forge inspect src/BETH.sol:BETH abi | jq -c '.'";
        bytes memory out = vm.ffi(pipe);
        bytes32 currentHash = keccak256(out);

        assertEq(currentHash, committedHash, "ABI snapshot changed; run make update-golden");
    }
}
