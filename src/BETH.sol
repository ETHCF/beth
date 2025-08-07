// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title BETH - Burned ETH
/// @notice Immutable ERC-20 token representing provably burnt ETH.
/// Sending ETH mints 1:1 BETH and forwards ETH to the burn address.
contract BETH is ERC20 {
    /// @dev Ethereum burn address
    address public constant ETH_BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    /// @dev Revert when a deposit with zero value is attempted
    error ZeroDeposit();
    /// @dev Revert when forwarding ETH to the burn address fails
    error ForwardFailed();

    /// @notice Emitted when ETH is forwarded to the burn address
    event Burned(address indexed from, uint256 amount);
    /// @notice Emitted when BETH is minted
    event Minted(address indexed to, uint256 amount);

    uint256 private _totalBurned;

    constructor() ERC20("BETH", "BETH") {}

    /// @inheritdoc ERC20
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /// @notice Total ETH permanently destroyed through this contract
    function totalBurned() external view returns (uint256) {
        return _totalBurned;
    }

    /// @notice Deposit ETH and mint BETH to the sender 1:1
    function deposit() external payable {
        _depositTo(msg.sender);
    }

    /// @notice Deposit ETH and mint BETH to a specified recipient 1:1
    /// @param recipient The address to receive minted BETH
    function depositTo(address recipient) external payable {
        _depositTo(recipient);
    }

    /// @notice Accept direct ETH transfers and mint BETH to the sender
    receive() external payable {
        _depositTo(msg.sender);
    }

    function _depositTo(address recipient) private returns (uint256 mintedAmount) {
        uint256 amount = msg.value;
        if (amount == 0) revert ZeroDeposit();

        // Forward ETH to the burn address
        (bool success, ) = payable(ETH_BURN_ADDRESS).call{value: amount}("");
        if (!success) revert ForwardFailed();

        // Mint BETH after successful forwarding
        _mint(recipient, amount);
        _totalBurned += amount;

        emit Burned(msg.sender, amount);
        emit Minted(recipient, amount);

        return amount;
    }
}
