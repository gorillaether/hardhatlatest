// hardhat.config.js - Complete Configuration

require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config(); // Loads variables from .env file into process.env

// Ensure you have these environment variables in your .env file:
// AMOY_RPC_URL="YOUR_ALCHEMY_AMOY_RPC_URL"
// PRIVATE_KEY="YOUR_WALLET_PRIVATE_KEY"
// POLYGONSCAN_API_KEY="YOUR_POLYGONSCAN_API_KEY"

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20", // Make sure this matches your contract's pragma compatibility
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      // Default local network for testing
    },
    amoy: {
      url: process.env.AMOY_RPC_URL || "", // Get Alchemy RPC URL from .env
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [], // Get private key from .env
      chainId: 80002, // Polygon Amoy Chain ID
    },
    // --- Optional Example Network Configurations (uncomment and configure if needed) ---
    // sepolia: {
    //    url: process.env.SEPOLIA_RPC_URL || "",
    //    accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    //    chainId: 11155111,
    // },
    // polygon: { // Example for Polygon Mainnet
    //   url: process.env.POLYGON_RPC_URL || "", // Needs POLYGON_RPC_URL in .env
    //   accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    //   chainId: 137,
    // }
    // mainnet: { // Example for Ethereum Mainnet
    //   url: process.env.MAINNET_RPC_URL || "", // Needs MAINNET_RPC_URL in .env
    //   accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    //   chainId: 1,
    // }
  },
  etherscan: {
    // Configure API keys for block explorers
    apiKey: {
       // IMPORTANT: Key name here must match the network name identifier used below and in commands
       amoy: process.env.POLYGONSCAN_API_KEY || "",

      // --- Optional Example API Key Configurations (uncomment and configure if needed) ---
      // mainnet: process.env.ETHERSCAN_API_KEY || "", // Needs ETHERSCAN_API_KEY in .env
      // polygon: process.env.POLYGONSCAN_API_KEY || "", // Uses the same key as Amoy typically
      // sepolia: process.env.ETHERSCAN_API_KEY || "", // Needs ETHERSCAN_API_KEY in .env
    },
    customChains: [
      {
        network: "amoy", // Network identifier string
        chainId: 80002,  // Chain ID for Amoy
        urls: {
          apiURL: "https://api-amoy.polygonscan.com/api", // API endpoint for Amoy verification
          browserURL: "https://amoy.polygonscan.com/"      // Block explorer URL for Amoy
        }
      }
      // Add configurations for other custom chains if needed
    ]
  },
  sourcify: {
    // Enable Sourcify verification (decentralized alternative)
    enabled: true
  }
};