import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const SubscriptionNFTModule = buildModule("SubscriptionNFTModule", (m) => {
  // Get initial owner from parameters, fallback to deployer account
  // You can override this per deployment with --parameters flag
  const initialOwner = m.getParameter("initialOwner", m.getAccount(0));

  // Deploy the SubscriptionNFT contract
  const subscriptionNFT = m.contract("SubscriptionNFT", [initialOwner]);

  return { subscriptionNFT };
});

export default SubscriptionNFTModule;