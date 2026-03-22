import 'dotenv/config';
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@matterlabs/hardhat-zksync-solc";
import "@matterlabs/hardhat-zksync-deploy";

// --- Retrieve Environment Variables ---
// Polygon Mainnet
const polygonMainnetRpcUrl = process.env.POLYGON_MAINNET_RPC_URL;
const polygonMainnetPrivateKey = process.env.POLYGON_MAINNET_PRIVATE_KEY;
const polygonscanMainnetApiKey = process.env.POLYGONSCAN_MAINNET_API_KEY;

// Polygon Amoy Testnet
const amoyRpcUrl = process.env.AMOY_RPC_URL;
const amoyPrivateKey = process.env.AMOY_PRIVATE_KEY;
const polygonscanAmoyApiKey = process.env.POLYGONSCAN_AMOY_API_KEY;

// zkSync Testnet (Era Sepolia / MetaMask chainId 300)
const zkSyncTestnetRpcUrl = process.env.ZKSYNC_TESTNET_RPC_URL || "https://sepolia.era.zksync.dev";
const zkSyncTestnetPrivateKey = process.env.ZKSYNC_TESTNET_PRIVATE_KEY;

// --- Debug ---
console.log("--------------------------------------------------------------------");
console.log("DEBUG: POLYGON_MAINNET_RPC_URL =", polygonMainnetRpcUrl);
console.log("DEBUG: AMOY_RPC_URL =", amoyRpcUrl);
console.log("DEBUG: ZKSYNC_TESTNET_RPC_URL =", zkSyncTestnetRpcUrl);
console.log("--------------------------------------------------------------------");

// --- Hardhat Configuration ---
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: { enabled: true, runs: 200 },
      viaIR: true, // enable intermediate representation to fix stack-too-deep errors
    },
  },
  networks: {
    hardhat: {},
    polygonMainnet: {
      url: polygonMainnetRpcUrl || "",
      accounts: polygonMainnetPrivateKey ? [polygonMainnetPrivateKey] : [],
      chainId: 137,
    },
    amoy: {
      url: amoyRpcUrl || "",
      accounts: amoyPrivateKey ? [amoyPrivateKey] : [],
      chainId: 80002,
    },
    zkSyncTestnet: {
      url: zkSyncTestnetRpcUrl,
      ethNetwork: "sepolia",
      zksync: true,
      accounts: zkSyncTestnetPrivateKey ? [zkSyncTestnetPrivateKey] : [],
      chainId: 300, // matches MetaMask
    },
  },
  etherscan: {
    apiKey: {
      polygon: polygonscanMainnetApiKey || "",
      polygonAmoy: polygonscanAmoyApiKey || "",
    },
    customChains: [
      {
        network: "polygonAmoy",
        chainId: 80002,
        urls: {
          apiURL: "https://api-amoy.polygonscan.com/api",
          browserURL: "https://amoy.polygonscan.com",
        },
      },
    ],
  },
  zksolc: {
    version: "1.3.5",
    compilerSource: "binary",
    settings: {},
  },
  namedAccounts: {
    deployer: { default: 0 },
  },
};

export default config;