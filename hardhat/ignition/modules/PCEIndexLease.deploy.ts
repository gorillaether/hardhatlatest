import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import "dotenv/config";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  console.log("----------------------------------------------------");
  console.log("📦 Deploying PCEIndexedLease contract");
  console.log("🌐 Network chainId:", chainId);
  console.log("👤 Deployer address:", deployer);
  console.log("----------------------------------------------------");

  let params: {
    landlord: string;
    tenant: string;
    payToken: string;
    pceFeed: string;
    baseRent: any;
    periodSeconds: number;
    startTime: number;
    endTime: number;
    upOnly: boolean;
    capUpPerPeriod1e18: any;
    capDownPerPeriod1e18: any;
    minRentFloor: any;
    lateFeeFixed: any;
  };

  switch (chainId) {
    case "80002": // Polygon Amoy Testnet
      params = {
        landlord: process.env.LANDLORD_ADDRESS || ethers.constants.AddressZero,
        tenant: process.env.TENANT_ADDRESS || ethers.constants.AddressZero,
        payToken: process.env.AMOY_USDC || ethers.constants.AddressZero,
        pceFeed: process.env.AMOY_PCE_FEED || ethers.constants.AddressZero,
        baseRent: ethers.utils.parseUnits("1000", 6),
        periodSeconds: 30 * 24 * 60 * 60,
        startTime: Math.floor(Date.now() / 1000),
        endTime: Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60,
        upOnly: true,
        capUpPerPeriod1e18: ethers.BigNumber.from("10000000000000000"),
        capDownPerPeriod1e18: ethers.BigNumber.from("10000000000000000"),
        minRentFloor: ethers.utils.parseUnits("500", 6),
        lateFeeFixed: ethers.utils.parseUnits("50", 6),
      };
      break;
    case "137": // Polygon Mainnet
      params = {
        landlord: process.env.LANDLORD_ADDRESS || ethers.constants.AddressZero,
        tenant: process.env.TENANT_ADDRESS || ethers.constants.AddressZero,
        payToken: process.env.POLYGON_USDC || ethers.constants.AddressZero,
        pceFeed: process.env.POLYGON_PCE_FEED || ethers.constants.AddressZero,
        baseRent: ethers.utils.parseUnits("1000", 6),
        periodSeconds: 30 * 24 * 60 * 60,
        startTime: Math.floor(Date.now() / 1000),
        endTime: Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60,
        upOnly: true,
        capUpPerPeriod1e18: ethers.BigNumber.from("10000000000000000"),
        capDownPerPeriod1e18: ethers.BigNumber.from("10000000000000000"),
        minRentFloor: ethers.utils.parseUnits("500", 6),
        lateFeeFixed: ethers.utils.parseUnits("50", 6),
      };
      break;
    case "300": // zkSync Era Testnet (Metamask hardcoded chainId)
      params = {
        landlord: process.env.LANDLORD_ADDRESS || ethers.constants.AddressZero,
        tenant: process.env.TENANT_ADDRESS || ethers.constants.AddressZero,
        payToken: process.env.ZKSYNC_USDC || ethers.constants.AddressZero,
        pceFeed: process.env.ZKSYNC_PCE_FEED || ethers.constants.AddressZero,
        baseRent: ethers.utils.parseUnits("1000", 6),
        periodSeconds: 30 * 24 * 60 * 60,
        startTime: Math.floor(Date.now() / 1000),
        endTime: Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60,
        upOnly: true,
        capUpPerPeriod1e18: ethers.BigNumber.from("10000000000000000"),
        capDownPerPeriod1e18: ethers.BigNumber.from("10000000000000000"),
        minRentFloor: ethers.utils.parseUnits("500", 6),
        lateFeeFixed: ethers.utils.parseUnits("50", 6),
      };
      break;
    default:
      throw new Error(`❌ No deployment parameters configured for chainId ${chainId}`);
  }

  const lease = await deploy("PCEIndexedLease", {
    from: deployer,
    args: [
      params.landlord,
      params.tenant,
      params.payToken,
      params.pceFeed,
      params.baseRent,
      params.periodSeconds,
      params.startTime,
      params.endTime,
      params.upOnly,
      params.capUpPerPeriod1e18,
      params.capDownPerPeriod1e18,
      params.minRentFloor,
      params.lateFeeFixed,
    ],
    log: true,
    autoMine: true,
  });

  console.log("----------------------------------------------------");
  console.log(`✅ PCEIndexedLease deployed at: ${lease.address}`);
  console.log("----------------------------------------------------");

  return lease.address;
};

export default func;
func.tags = ["PCEIndexedLease"];