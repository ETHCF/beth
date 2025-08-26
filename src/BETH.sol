// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title BETH - Burned ETH
/// @notice Immutable ERC-20 token representing provably burnt ETH. Sending ETH mints 1:1 BETH and forwards
/// the ETH to the canonical burn address.
/// @author Built by Zak Cole (x.com/0xzak, github.com/zscole) at Number Group (numbergroup.xyz) for the Ethereum Community Foundation (ethcf.org).
/// @dev This contract is non-upgradeable and has no privileged roles. It relies on ETH forwarding via
/// low-level call; failures revert. Forced ETH (e.g., via selfdestruct) can be flushed without minting.
contract BETH is ERC20 {
    /// @notice Canonical Ethereum burn address used as the ETH sink
    /// @dev This is a constant well-known address to which ETH is forwarded
    address public constant ETH_BURN_ADDRESS = 0x0000000000000000000000000000000000000000;

    /// @notice Error for zero-value deposits
    /// @dev Thrown when msg.value == 0 in deposit paths
    error ZeroDeposit();
    /// @notice Error when forwarding ETH fails
    /// @dev Thrown if the low-level call to the burn address returns false
    error ForwardFailed();

    /// @notice Emitted when ETH is forwarded to the burn address
    /// @param from The address providing the ETH being forwarded
    /// @param amount The amount of ETH forwarded, in wei
    event Burned(address indexed from, uint256 amount);
    /// @notice Emitted when BETH is minted
    /// @param to The address receiving newly minted BETH
    /// @param amount The amount of BETH minted, in wei (1:1 with ETH)
    event Minted(address indexed to, uint256 amount);

    uint256 private _totalBurned;

    /// @notice Deploy the BETH token
    /// @dev Initializes the ERC-20 name and symbol
    constructor() ERC20("BETH", "BETH") { }

    /// @inheritdoc ERC20
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /// @notice Total ETH permanently destroyed through this contract
    /// @dev Tracks ETH forwarded via deposits/receive and via flush(); does not include unflushed forced ETH
    /// @return burned The cumulative ETH amount accounted as burned, in wei
    function totalBurned() external view returns (uint256 burned) {
        return _totalBurned;
    }

    /// @notice Deposit ETH and mint BETH to the sender 1:1
    /// @dev Reverts on zero-value; forwards ETH before minting
    function deposit() external payable {
        _depositTo(msg.sender);
    }

    /// @notice Deposit ETH and mint BETH to a specified recipient 1:1
    /// @dev Reverts on zero-value; forwards ETH before minting
    /// @param recipient The address to receive minted BETH
    function depositTo(address recipient) external payable {
        _depositTo(recipient);
    }

    /// @notice Accept direct ETH transfers and mint BETH to the sender
    /// @dev Forwards ETH before minting; identical accounting to deposit()
    receive() external payable {
        _depositTo(msg.sender);
    }

    /// @notice Forward any stray ETH balance to the burn address without minting
    /// @dev Handles ETH force-sent to the contract (e.g., via selfdestruct). Increases totalBurned only.
    function flush() external {
        uint256 amount = address(this).balance;
        if (amount == 0) return;
        // Effects first to satisfy static analyzers; revert will roll back on failure below
        _totalBurned += amount;
        emit Burned(address(this), amount);
        (bool success,) = payable(ETH_BURN_ADDRESS).call{ value: amount }("");
        if (!success) revert ForwardFailed();
    }

    /// @notice Internal helper to forward ETH then mint BETH 1:1
    /// @dev Forwards ETH to the burn address, then mints to `recipient` on success.
    /// @param recipient The address to receive newly minted BETH
    /// @return mintedAmount The amount of BETH minted, in wei
    function _depositTo(address recipient) private returns (uint256 mintedAmount) {
        uint256 amount = msg.value;
        if (amount == 0) revert ZeroDeposit();

        // Forward ETH to the burn address
        (bool success,) = payable(ETH_BURN_ADDRESS).call{ value: amount }("");
        if (!success) revert ForwardFailed();

        // Mint BETH after successful forwarding
        _mint(recipient, amount);
        _totalBurned += amount;

        emit Burned(msg.sender, amount);
        emit Minted(recipient, amount);

        return amount;
    }
}
