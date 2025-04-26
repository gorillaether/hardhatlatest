// mint.js - Corrected Script

require("dotenv").config();
const hre = require("hardhat");
const { ethers } = hre;

// The address of the deployed MarketMood contract on Amoy
const CONTRACT_ADDRESS = "0xFd4be49e5D6674D32A33E7f512C651E6EABb731d";
// The address where the new NFT will be sent (e.g., your own wallet)
// We get this from the deployer/signer automatically below
// const RECIPIENT_ADDRESS = "REPLACE_WITH_RECIPIENT_ADDRESS"; // Or use deployer.address

async function main() {
  const [deployer] = await ethers.getSigners();
  const recipientAddress = deployer.address; // Minting to the deployer's address by default

  console.log("Minting NFT to:", recipientAddress);
  console.log("Using contract:", CONTRACT_ADDRESS);
  console.log("Minting initiated by wallet:", deployer.address);

  // Get the contract instance using the correct name "MarketMood" and connect the signer
  const marketMoodContract = await ethers.getContractAt("MarketMood", CONTRACT_ADDRESS, deployer);

  // --- Call the CORRECT function 'safeMint' with the CORRECT argument ---
  console.log(`Calling safeMint(${recipientAddress})...`);
  const tx = await marketMoodContract.safeMint(recipientAddress);
  // --- End of corrected call ---

  console.log("Mint transaction sent! Waiting for confirmation...");
  console.log("Transaction hash:", tx.hash);

  // Wait for the transaction to be mined
  await tx.wait();

  console.log("✅ NFT minted successfully! Token ID should be 0 for the first mint.");
  // Note: To know the exact Token ID, you would need to listen for the Transfer event
  // or call the contract's totalSupply (if implemented) or check manually on explorer.
  // Our internal counter starts at 0, so the first token ID will be 0.
}

main().catch((err) => {
  console.error("❌ Error during minting process:", err);
  process.exit(1);
});