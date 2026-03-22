// ignition/modules/DeployErgoCity.js
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

// Module ID: A unique string to identify your module.
const MODULE_ID = "ErgoCityModule";

module.exports = buildModule(MODULE_ID, (m) => {
  // The 'm' object is the ModuleBuilder, used to define actions.

  // Define the deployment of the "ErgoCity" contract.
  // Since your ErgoCity contract's constructor is:
  // constructor() Ownable(msg.sender) {}
  // It takes no arguments that need to be passed here.
  // The account deploying this module will automatically become the owner.
  const ergoCity = m.contract("ErgoCity");

  // The module should return an object containing the deployed contracts (as "Futures").
  // This allows you to access their deployed addresses and other info later.
  return { ergoCity };
});