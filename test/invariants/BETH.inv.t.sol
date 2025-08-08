// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { BETH } from "src/BETH.sol";
import { ExploitForceETH } from "test/utils/ExploitForceETH.sol";

contract InvariantHandler is StdCheats, StdUtils, Test {
    BETH public immutable beth;

    address[] public actors;
    mapping(address => uint256) public ledger; // expected balances
    uint256 public expectedTotalSupply;
    uint256 public expectedTotalBurned;
    uint256 public forcedETHAccumulated;
    bool public lastActionWasLegitDeposit;

    constructor(BETH _beth) {
        beth = _beth;
        // Seed a pool of actor addresses
        for (uint160 i = 1; i <= 20; i++) {
            actors.push(address(i));
        }
    }

    function _pickActor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    // Legitimate mint paths
    function hDeposit(uint96 amount, uint256 seed) external {
        amount = uint96(bound(amount, 1, 10 ether));
        address actor = _pickActor(seed);
        hoax(actor, amount);
        beth.deposit{ value: amount }();
        ledger[actor] += amount;
        expectedTotalSupply += amount;
        expectedTotalBurned += amount;
        lastActionWasLegitDeposit = true;
    }

    function hDepositTo(uint96 amount, uint256 senderSeed, uint256 recSeed) external {
        amount = uint96(bound(amount, 1, 10 ether));
        address sender = _pickActor(senderSeed);
        address recipient = _pickActor(recSeed);
        hoax(sender, amount);
        beth.depositTo{ value: amount }(recipient);
        ledger[recipient] += amount;
        expectedTotalSupply += amount;
        expectedTotalBurned += amount;
        lastActionWasLegitDeposit = true;
    }

    function hReceive(uint96 amount, uint256 seed) external {
        amount = uint96(bound(amount, 1, 10 ether));
        address actor = _pickActor(seed);
        hoax(actor, amount);
        (bool ok,) = address(beth).call{ value: amount }("");
        if (ok) {
            ledger[actor] += amount;
            expectedTotalSupply += amount;
            expectedTotalBurned += amount;
        }
        lastActionWasLegitDeposit = true;
    }

    // ERC20 operations
    function hTransfer(uint256 fromSeed, uint256 toSeed, uint96 amtSeed) external {
        address from = _pickActor(fromSeed);
        address to = _pickActor(toSeed);
        uint256 bal = ledger[from];
        if (bal == 0 || from == to) {
            lastActionWasLegitDeposit = false;
            return;
        }
        uint256 send = bound(uint256(amtSeed), 1, bal);
        vm.prank(from);
        beth.transfer(to, send);
        ledger[from] -= send;
        ledger[to] += send;
        lastActionWasLegitDeposit = false;
    }

    function hApprove(uint256 ownerSeed, uint256 spenderSeed, uint96 amt) external {
        address owner = _pickActor(ownerSeed);
        address spender = _pickActor(spenderSeed);
        vm.prank(owner);
        beth.approve(spender, amt);
        lastActionWasLegitDeposit = false;
    }

    function hTransferFrom(uint256 ownerSeed, uint256 spenderSeed, uint96 amtSeed) external {
        address owner = _pickActor(ownerSeed);
        address spender = _pickActor(spenderSeed);
        uint256 bal = ledger[owner];
        if (bal == 0) {
            lastActionWasLegitDeposit = false;
            return;
        }
        uint256 send = bound(uint256(amtSeed), 1, bal);
        // Ensure allowance
        vm.prank(owner);
        beth.approve(spender, send);
        vm.prank(spender);
        beth.transferFrom(owner, spender, send);
        ledger[owner] -= send;
        ledger[spender] += send;
        lastActionWasLegitDeposit = false;
    }

    // Force ETH via selfdestruct, not a legitimate mint path
    function hForceETH(uint96 amount) external {
        amount = uint96(bound(amount, 1, 5 ether));
        ExploitForceETH ex = new ExploitForceETH();
        deal(address(ex), amount);
        ex.boom(address(beth));
        forcedETHAccumulated += amount;
        lastActionWasLegitDeposit = false;
    }

    // Views for invariants
    function sumLedger() external view returns (uint256 sum) {
        for (uint256 i = 0; i < actors.length; i++) {
            sum += ledger[actors[i]];
        }
    }
}

contract BETHInvariantSuite is Test {
    BETH internal beth;
    InvariantHandler internal handler;

    function setUp() public {
        beth = new BETH();
        handler = new InvariantHandler(beth);

        // Target handler with multiple selectors
        bytes4[] memory sels = new bytes4[](7);
        sels[0] = handler.hDeposit.selector;
        sels[1] = handler.hDepositTo.selector;
        sels[2] = handler.hReceive.selector;
        sels[3] = handler.hTransfer.selector;
        sels[4] = handler.hApprove.selector;
        sels[5] = handler.hTransferFrom.selector;
        sels[6] = handler.hForceETH.selector;
        targetSelector(FuzzSelector({ addr: address(handler), selectors: sels }));
        targetContract(address(handler));

        // Widen actor space
        for (uint160 i = 1; i <= 20; i++) {
            targetSender(address(i));
        }
    }

    function invariant_SupplyEqualsBurned_AndNoHiddenMint() public {
        // totalSupply always equals totalBurned
        assertEq(beth.totalSupply(), beth.totalBurned());
        // totalSupply equals sum of ledger; handler.expectedTotalSupply is a running mirror but
        // may diverge if flush burns forced ETH without minting. So rely on live sum instead.
        uint256 sum = handler.sumLedger();
        assertEq(beth.totalSupply(), sum);
    }

    function invariant_LedgerSumEqualsSupply() public {
        uint256 sum = handler.sumLedger();
        assertEq(sum, beth.totalSupply());
    }

    function invariant_ContractBalanceBoundedByForcedETH() public {
        // Contract balance is at most the forced ETH that hasn't yet been flushed.
        // A flush() call can reduce forcedETHAccumulated by moving ETH to burn and increasing totalBurned
        // without minting. So we only assert the upper bound here.
        assertLe(address(beth).balance, handler.forcedETHAccumulated());
    }
}
