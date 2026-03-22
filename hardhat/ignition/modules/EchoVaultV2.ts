import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const EchoVaultV2Module = buildModule("EchoVaultV2Module", (m) => {
  // Deploy the V2 contract (no constructor args needed)
  const echoVaultV2 = m.contract("EchoVaultV2", []);

  return { echoVaultV2 };
});

export default EchoVaultV2Module;