// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {BETH} from "src/BETH.sol";
import {ExploitForceETH} from "test/utils/ExploitForceETH.sol";

contract _SDPusher {
    constructor() payable {}
    function boom(address payable target) external {
        selfdestruct(target);
    }
}

contract BETHTest is Test {
    BETH internal beth;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal constant BURN = address(0x000000000000000000000000000000000000dEaD);

    function setUp() public {
        beth = new BETH();
    }

    // Mirror events to enable expectEmit matching
    event Burned(address indexed from, uint256 amount);
    event Minted(address indexed to, uint256 amount);

    // Mirror OZ v5 custom error for zero-address mint
    error ERC20InvalidReceiver(address receiver);

    function test_DecimalsIs18() public view {
        assertEq(beth.decimals(), 18);
    }

    function test_Deposit_MintsAndForwards() public {
        vm.deal(alice, 10 ether);
        uint256 burnBefore = BURN.balance;

        vm.prank(alice);
        beth.deposit{value: 1 ether}();
        assertEq(beth.balanceOf(alice), 1 ether);
        assertEq(beth.totalBurned(), 1 ether);
        assertEq(address(beth).balance, 0);
        assertEq(BURN.balance, burnBefore + 1 ether);
    }

    function test_Deposit_EventsAndAccounting_1Wei() public {
        vm.deal(alice, 1 ether);
        uint256 burnBefore = BURN.balance;

        vm.prank(alice);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Burned(alice, 1);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Minted(alice, 1);
        beth.deposit{value: 1}();

        assertEq(beth.balanceOf(alice), 1);
        assertEq(beth.totalSupply(), 1);
        assertEq(beth.totalBurned(), 1);
        assertEq(address(beth).balance, 0);
        assertEq(BURN.balance, burnBefore + 1);
    }

    function test_Deposit_EventsAndAccounting_1Ether() public {
        vm.deal(alice, 2 ether);
        uint256 burnBefore = BURN.balance;

        vm.prank(alice);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Burned(alice, 1 ether);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Minted(alice, 1 ether);
        beth.deposit{value: 1 ether}();

        assertEq(beth.balanceOf(alice), 1 ether);
        assertEq(beth.totalSupply(), 1 ether);
        assertEq(beth.totalBurned(), 1 ether);
        assertEq(address(beth).balance, 0);
        assertEq(BURN.balance, burnBefore + 1 ether);
    }

    function test_Deposit_EventsAndAccounting_Large() public {
        uint256 amount = 1_000_000 ether; // large value
        vm.deal(alice, amount);
        uint256 burnBefore = BURN.balance;

        vm.prank(alice);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Burned(alice, amount);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Minted(alice, amount);
        beth.deposit{value: amount}();

        assertEq(beth.balanceOf(alice), amount);
        assertEq(beth.totalSupply(), amount);
        assertEq(beth.totalBurned(), amount);
        assertEq(address(beth).balance, 0);
        assertEq(BURN.balance, burnBefore + amount);
    }

    function test_DepositTo_MintsToRecipientAndForwards() public {
        vm.deal(alice, 10 ether);
        uint256 burnBefore = BURN.balance;

        vm.prank(alice);
        beth.depositTo{value: 2 ether}(bob);
        assertEq(beth.balanceOf(bob), 2 ether);
        assertEq(beth.totalBurned(), 2 ether);
        assertEq(address(beth).balance, 0);
        assertEq(BURN.balance, burnBefore + 2 ether);
    }

    function test_DepositTo_MultipleSenders_NoStateBleed() public {
        address sender1 = address(0xAAA1);
        address sender2 = address(0xAAA2);
        address recipient = address(0xBEEF);
        vm.deal(sender1, 5 ether);
        vm.deal(sender2, 7 ether);

        vm.prank(sender1);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Burned(sender1, 2 ether);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Minted(recipient, 2 ether);
        beth.depositTo{value: 2 ether}(recipient);

        vm.prank(sender2);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Burned(sender2, 3 ether);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Minted(recipient, 3 ether);
        beth.depositTo{value: 3 ether}(recipient);

        assertEq(beth.balanceOf(recipient), 5 ether);
        assertEq(beth.balanceOf(sender1), 0);
        assertEq(beth.balanceOf(sender2), 0);
    }

    function test_DepositTo_ZeroAddress_Reverts_OZGuard() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20InvalidReceiver.selector, address(0)));
        beth.depositTo{value: 1 ether}(address(0));
    }

    function _deployMinimalProxy(address implementation) internal returns (address proxy) {
        bytes memory creation = abi.encodePacked(
            hex"3d602d80600a3d3981f3",
            hex"363d3d373d3d3d363d73",
            implementation,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
        assembly {
            proxy := create(0, add(creation, 32), mload(creation))
        }
        require(proxy != address(0), "proxy deploy failed");
    }

    function test_DepositTo_EOA_And_MinimalProxy_IdenticalBehavior() public {
        address eoa = address(0xE0A);
        address impl = address(this); // any implementation target
        address proxy = _deployMinimalProxy(impl);

        vm.deal(alice, 7 ether);

        // To EOA
        vm.prank(alice);
        beth.depositTo{value: 3 ether}(eoa);

        // To minimal proxy
        vm.prank(alice);
        beth.depositTo{value: 4 ether}(proxy);

        assertEq(beth.balanceOf(eoa), 3 ether);
        assertEq(beth.balanceOf(proxy), 4 ether);
    }

    function test_FallbackWithData_Reverts_NoMint() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool ok, ) = address(beth).call{value: 0.5 ether}(hex"616263");
        assertFalse(ok);
        assertEq(beth.balanceOf(alice), 0);
        assertEq(address(beth).balance, 0);
    }

    // The following tests document the EVM limitation: ETH can be force-sent to any contract via
    // selfdestruct. This ETH is not minted to anyone and cannot be withdrawn by the contract as per spec.
    // We additionally demonstrate that normal deposit/receive flows do not absorb or leak this forced ETH.
    function test_ForcedETH_IncreasesBalance_NoMint() public {
        ExploitForceETH ex = new ExploitForceETH();
        vm.deal(address(ex), 1 ether);
        ex.boom(address(beth));

        assertEq(address(beth).balance, 1 ether);
        assertEq(beth.totalBurned(), 0);
        assertEq(beth.totalSupply(), 0);
    }

    function test_AfterDeposit_ContractBalanceEqualsPriorForcedETH() public {
        // Force 1 ether without mint
        ExploitForceETH ex = new ExploitForceETH();
        vm.deal(address(ex), 1 ether);
        ex.boom(address(beth));
        assertEq(address(beth).balance, 1 ether);

        // Legitimate deposit forwards only the msg.value and does not touch forced ETH
        vm.deal(alice, 2 ether);
        uint256 burnBefore = BURN.balance;
        vm.prank(alice);
        beth.deposit{value: 2 ether}();

        // Post-conditions: user minted, burn increased by deposit amount, forced 1 ETH remains stuck
        assertEq(beth.balanceOf(alice), 2 ether);
        assertEq(beth.totalBurned(), 2 ether);
        assertEq(BURN.balance, burnBefore + 2 ether);
        assertEq(address(beth).balance, 1 ether);
    }

    function test_Invariant_AfterAnyLegitDeposit_ContractBalanceEqualsPreviouslyForced() public {
        // Force-send 1.5 ETH first
        ExploitForceETH ex = new ExploitForceETH();
        vm.deal(address(ex), 1.5 ether);
        ex.boom(address(beth));
        assertEq(address(beth).balance, 1.5 ether);

        // Multiple legitimate mints should not change the forced balance
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        beth.deposit{value: 1 ether}();
        vm.prank(alice);
        (bool ok, ) = payable(address(beth)).call{value: 2 ether}("");
        assertTrue(ok);

        // The contract's own balance is exactly the previously forced ETH
        assertEq(address(beth).balance, 1.5 ether);
    }

    function test_MultipleSequentialDeposits_AdditiveAndMonotonic() public {
        vm.deal(alice, 10 ether);
        uint256 tb0 = beth.totalBurned();

        vm.prank(alice);
        beth.deposit{value: 1 ether}();
        assertEq(beth.balanceOf(alice), 1 ether);
        assertEq(beth.totalBurned(), tb0 + 1 ether);

        vm.prank(alice);
        beth.deposit{value: 2 ether}();
        assertEq(beth.balanceOf(alice), 3 ether);
        assertEq(beth.totalBurned(), tb0 + 3 ether);

        vm.prank(alice);
        beth.deposit{value: 0.5 ether}();
        assertEq(beth.balanceOf(alice), 3.5 ether);
        assertEq(beth.totalBurned(), tb0 + 3.5 ether);
    }

    function test_Receive_MintsToSender() public {
        vm.deal(alice, 5 ether);
        uint256 burnBefore = BURN.balance;

        vm.prank(alice);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Burned(alice, 3 ether);
        vm.expectEmit(true, false, false, true, address(beth));
        emit Minted(alice, 3 ether);
        (bool ok, ) = payable(address(beth)).call{value: 3 ether}("");
        assertTrue(ok);

        assertEq(beth.balanceOf(alice), 3 ether);
        assertEq(beth.totalBurned(), 3 ether);
        assertEq(address(beth).balance, 0);
        assertEq(BURN.balance, burnBefore + 3 ether);
    }

    function test_Flush_ForwardsForcedETH() public {
        // Force ETH via selfdestruct without invoking BETH.receive
        _SDPusher p = new _SDPusher{value: 2 ether}();
        p.boom(payable(address(beth)));

        uint256 burnBefore = BURN.balance;
        uint256 burnedBefore = beth.totalBurned();

        beth.flush();

        assertEq(address(beth).balance, 0);
        assertEq(BURN.balance, burnBefore + 2 ether);
        assertEq(beth.totalBurned(), burnedBefore + 2 ether);
    }

    function test_RevertOnZeroDeposit_Deposit() public {
        vm.expectRevert(BETH.ZeroDeposit.selector);
        beth.deposit{value: 0}();
    }

    function test_RevertOnZeroDeposit_DepositTo() public {
        vm.expectRevert(BETH.ZeroDeposit.selector);
        beth.depositTo{value: 0}(bob);
    }

    function test_Forward_Succeeds_DeadAddress_NeverReverts() public {
        vm.deal(alice, 4 ether);
        uint256 burnBefore = BURN.balance;

        vm.prank(alice);
        beth.deposit{value: 4 ether}();

        // If forwarding failed, state would have reverted. Post-conditions assert success.
        assertEq(beth.balanceOf(alice), 4 ether);
        assertEq(beth.totalBurned(), 4 ether);
        assertEq(address(beth).balance, 0);
        assertEq(BURN.balance, burnBefore + 4 ether);
    }

    function test_ERC20_Transfer() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        beth.deposit{value: 1 ether}();

        vm.prank(alice);
        bool success = beth.transfer(bob, 0.4 ether);
        assertTrue(success);
        assertEq(beth.balanceOf(alice), 0.6 ether);
        assertEq(beth.balanceOf(bob), 0.4 ether);
    }

    function test_ERC20_ApproveAndTransferFrom() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        beth.deposit{value: 1 ether}();

        vm.prank(alice);
        beth.approve(bob, 0.5 ether);
        assertEq(beth.allowance(alice, bob), 0.5 ether);

        vm.prank(bob);
        bool success = beth.transferFrom(alice, bob, 0.5 ether);
        assertTrue(success);
        assertEq(beth.balanceOf(alice), 0.5 ether);
        assertEq(beth.balanceOf(bob), 0.5 ether);
    }
}
