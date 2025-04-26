const { ethers } = require("hardhat");

async function main() {
  const newBaseURI = process.argv[2];
  if (!newBaseURI) {
    throw new Error("Please provide the new baseURI as an argument.");
  }

  const contractAddress = "0xFd4be49e5D6674D32A33E7f512C651E6EABb731d"; // Your deployed contract address

  const Contract = await ethers.getContractFactory("MarketMood");
  const contract = await Contract.attach(contractAddress);

  console.log(`Setting baseURI to: ${newBaseURI}`);
  const tx = await contract.setBaseURI(newBaseURI);
  await tx.wait();
  console.log(`BaseURI set successfully! Transaction hash: ${tx.hash}`);
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error);
  process.exit(1);
});