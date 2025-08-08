// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @notice Test-only harness that mimics BETH but allows configurable forward target
/// Production bytecode is unchanged; this is only for reentrancy simulation tests.
contract BETHReentryHarness is ERC20 {
    address public forwardTarget;

    error ZeroDeposit();
    error ForwardFailed();

    event Burned(address indexed from, uint256 amount);
    event Minted(address indexed to, uint256 amount);

    uint256 private _totalBurned;

    constructor(address _forwardTarget) ERC20("BETH", "BETH") {
        forwardTarget = _forwardTarget;
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function totalBurned() external view returns (uint256) {
        return _totalBurned;
    }

    function setForwardTarget(address _target) external {
        forwardTarget = _target;
    }

    function deposit() external payable {
        _depositTo(msg.sender);
    }

    function depositTo(address recipient) external payable {
        _depositTo(recipient);
    }

    receive() external payable {
        _depositTo(msg.sender);
    }

    // Internal-only hook not externally callable; fake burn will attempt to call it and fail
    function onForwardCallback() external pure {
        // Not reachable from external call context since this function is external but reverts deliberately
        revert("no-callback");
    }

    function _depositTo(address recipient) private returns (uint256) {
        uint256 amount = msg.value;
        if (amount == 0) revert ZeroDeposit();

        (bool success,) = payable(forwardTarget).call{ value: amount }("");
        if (!success) revert ForwardFailed();

        _mint(recipient, amount);
        _totalBurned += amount;
        emit Burned(msg.sender, amount);
        emit Minted(recipient, amount);
        return amount;
    }
}
