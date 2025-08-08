// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { BETH } from "src/BETH.sol";

contract RevertingSender {
    function doDepositThenRevert(BETH beth, uint256 amount) external payable {
        beth.deposit{ value: amount }();
        revert("sender reverted after deposit");
    }

    receive() external payable {
        revert("unexpected receive");
    }
}

contract SelfDestructSender {
    function depositThenSelfDestruct(BETH beth, uint256 amount, address payable payout)
        external
        payable
    {
        beth.deposit{ value: amount }();
        selfdestruct(payout);
    }
}

contract SenderEdgeCases is Test {
    BETH internal beth;
    address internal constant BURN = address(0x000000000000000000000000000000000000dEaD);

    function setUp() public {
        beth = new BETH();
    }

    function testFuzz_RevertingSender_DoesNotPersistMint(uint96 amount) public {
        vm.assume(amount > 0);
        RevertingSender s = new RevertingSender();
        vm.deal(address(s), amount);
        uint256 burnBefore = BURN.balance;
        uint256 tsBefore = beth.totalSupply();
        uint256 tbBefore = beth.totalBurned();
        uint256 contractBefore = address(beth).balance;
        (bool ok,) = address(s).call{ value: amount }(
            abi.encodeWithSelector(RevertingSender.doDepositThenRevert.selector, beth, amount)
        );
        assertFalse(ok);
        assertEq(BURN.balance, burnBefore);
        assertEq(beth.totalSupply(), tsBefore);
        assertEq(beth.totalBurned(), tbBefore);
        assertEq(address(beth).balance, contractBefore);
    }

    function testFuzz_SelfDestructSender_StateConsistent(uint96 amount, address payout) public {
        vm.assume(amount > 0);
        vm.assume(payout != address(0));
        SelfDestructSender s = new SelfDestructSender();
        address payable senderAddr = payable(address(s));
        vm.deal(senderAddr, amount);
        uint256 burnBefore = BURN.balance;
        uint256 tsBefore = beth.totalSupply();
        uint256 tbBefore = beth.totalBurned();
        (bool ok,) = senderAddr.call{ value: amount }(
            abi.encodeWithSelector(
                SelfDestructSender.depositThenSelfDestruct.selector, beth, amount, payable(payout)
            )
        );
        assertTrue(ok);
        assertEq(beth.balanceOf(senderAddr), amount);
        assertEq(beth.totalSupply(), tsBefore + amount);
        assertEq(beth.totalBurned(), tbBefore + amount);
        assertEq(BURN.balance, burnBefore + amount);
    }
}
