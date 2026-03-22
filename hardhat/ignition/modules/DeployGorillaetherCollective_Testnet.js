// ignition/modules/DeployGorillaetherCollective.js

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

// Updated Module ID for testnet deployment
const MODULE_ID = "GorillaetherCollectiveModule_Testnet";

module.exports = buildModule(MODULE_ID, (m) => {
    // The 'm' object is the ModuleBuilder.

    // Define the initial membership fee: 0.01 MATIC (0.01 * 10^18 wei)
    // This is much more reasonable for testnet faucets
    const initialMembershipFee = 10_000_000_000_000_000n; // 0.01 MATIC in wei

    // Deploy the "GorillaetherCollective" contract.
    // Ensure this string exactly matches the contract name in your .sol file.
    const gorillaetherCollective = m.contract("GorillaetherCollective", [initialMembershipFee]);

    // Update the key in the returned object to match the variable name for consistency.
    return { gorillaetherCollective };
});