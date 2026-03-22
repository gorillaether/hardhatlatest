import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const EchoVaultModule = buildModule("EchoVaultModule", (m) => {
  // Treasury address (where subscription/creation fees go)
  const treasuryAddress = m.getParameter(
    "treasuryAddress", 
    "0x3a0FDE60366D9ee620b85d8C19418a9D6067Bf86"
  );
  
  // Platform wallet (can create capsules for users - gasless UX)
  // IMPORTANT: Generate a new wallet for this and fund with MATIC
  // This wallet will pay gas for user transactions in Web 2.5 mode
  const platformWalletAddress = m.getParameter(
    "platformWalletAddress",
    "0x3a0FDE60366D9ee620b85d8C19418a9D6067Bf86" // CHANGE THIS - should be separate wallet
  );
  
  const echoVault = m.contract("EchoVault", [
    treasuryAddress,
    platformWalletAddress
  ]);

  return { echoVault };
});

export default EchoVaultModule;
