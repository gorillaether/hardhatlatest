import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const EchoVaultV3Module = buildModule("EchoVaultV3Module", (m) => {
  // Deploy the V3 contract (no constructor args needed)
  const echoVaultV3 = m.contract("EchoVaultV3", []);

  // Add custodial wallet as admin
  const custodialWallet = "0x8bfF978e695d0D4c28fe294866AeA1bffACf2249";
  
  m.call(echoVaultV3, "addAdmin", [custodialWallet]);

  return { echoVaultV3 };
});

export default EchoVaultV3Module;