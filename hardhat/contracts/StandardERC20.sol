// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import the standard ERC20 contract and Ownable for security.
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StandardERC20
 * @dev This contract creates a standard ERC20 token.
 * - The person who deploys it becomes the "Owner".
 * - The total initial supply is minted to the Owner's address upon creation.
 */
contract StandardERC20 is ERC20, Ownable {
    /**
     * @dev The constructor is called only once, when the contract is deployed.
     * @param name The name of the new token (e.g., "My Token").
     * @param symbol The symbol of the new token (e.g., "MTK").
     * @param initialSupply The total number of tokens to create.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        // Most ERC20 tokens have 18 decimal places. To create 1,000,000 tokens,
        // we actually need to create 1,000,000 * 10^18 of the smallest unit.
        // Ethers.js will handle this calculation for us, so we mint the exact value passed in.
        _mint(msg.sender, initialSupply);
    }
}