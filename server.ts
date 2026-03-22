import express, { Express, Request, Response } from 'express';
import { ethers, Contract, Wallet, JsonRpcProvider } from 'ethers';
import cors from 'cors';
import 'dotenv/config';

// TypeScript can import JSON files directly with the right config
import contractArtifact from './artifacts/contracts/Soulbound.sol/Soulbound.json';

const app: Express = express();
app.use(cors());
app.use(express.json());

// --- Environment Variable Validation ---
const rpcUrl = process.env.AMOY_RPC_URL;
const privateKey = process.env.AMOY_PRIVATE_KEY;
const contractAddress = process.env.SOULBOUND_CONTRACT_ADDRESS;

if (!rpcUrl || !privateKey || !contractAddress) {
  throw new Error("Missing required environment variables!");
}

// --- Ethers.js Setup ---
const provider: JsonRpcProvider = new ethers.JsonRpcProvider(rpcUrl);
const wallet: Wallet = new ethers.Wallet(privateKey, provider);
const contractABI: any[] = contractArtifact.abi;

// Create a typed contract instance
const soulboundContract: Contract = new ethers.Contract(contractAddress, contractABI, wallet);

// --- API Endpoints ---
app.get('/contract-name', async (req: Request, res: Response) => {
  try {
    // Replace 'name' with a real read-only function from your Soulbound.sol
    const name: string = await soulboundContract.name();
    res.json({ name });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch contract name' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Backend server running on port ${PORT}`));