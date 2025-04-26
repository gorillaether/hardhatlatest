// ignition/modules/DeployMarketMood.js
// Updated for constructor expecting initialOwner

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

// A unique ID for your deployment module
const MARKET_MOOD_MODULE_ID = "MarketMoodModule";

module.exports = buildModule(MARKET_MOOD_MODULE_ID, (m) => {
  // Get the address of the account deploying the contract (account 0)
  // This account will become the initial owner.
  const initialOwner = m.getAccount(0);

  console.log(`Deployer address (initial owner): ${initialOwner}`); // Log the owner address

  // Deploy the "MarketMood" contract.
  // Pass the initialOwner address as the first argument to the constructor.
  const marketMood = m.contract("MarketMood", [initialOwner]);

  console.log(`Deployment module for MarketMood contract defined.`);
  console.log(`Initiating deployment via Hardhat Ignition...`);

  // Return the deployed contract instance
  return { marketMood };
});