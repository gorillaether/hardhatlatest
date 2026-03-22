// scripts/checkContractState.js
const hre = require("hardhat");

// Your deployed StoicAvatarNFT contract's address on Amoy
const CONTRACT_ADDRESS = "0x6a856c10Cb553D7a2F33E66138940A6B53E32025";

// AvatarStages enum values (matching your Solidity enum)
const AvatarStages = {
    Novice: 0,
    Apprentice: 1,
    // Add other stages here if you want to check them too
    // Practitioner: 2,
    // Scholar: 3,
    // Sage: 4,
    // Epictetus: 5
};

async function main() {
    console.log(`Querying state for contract at: ${CONTRACT_ADDRESS}`);
    console.log(`Target network: ${hre.network.name}`);
    console.log("----------------------------------------------------");

    // Ensure your contract has been compiled for Hardhat to find its artifact (ABI)
    const StoicAvatarNFTFactory = await hre.ethers.getContractFactory("StoicAvatarNFT");
    const stoicAvatarNFTContract = StoicAvatarNFTFactory.attach(CONTRACT_ADDRESS);

    // 1. Check the owner
    try {
        const ownerAddress = await stoicAvatarNFTContract.owner();
        console.log(`1. Contract Owner: ${ownerAddress}`);
        const expectedOwner = "0x3a0fde60366d9ee620b85d8c19418a9d6067bf86"; // Your deployer address
        if (ownerAddress.toLowerCase() === expectedOwner.toLowerCase()) {
            console.log("   ✅ Ownership matches your expected deployer address.");
        } else {
            console.log(`   ⚠️ Ownership DOES NOT match. Expected: ${expectedOwner}`);
        }
    } catch (error) {
        console.error("   ❌ Error fetching owner:", error.message);
    }
    console.log("----------------------------------------------------");

    // 2. Check URI for Novice Stage (Stage 0)
    try {
        const noviceURI = await stoicAvatarNFTContract.getStageTokenURIBase(AvatarStages.Novice);
        console.log(`2. URI for Novice stage (Enum Value ${AvatarStages.Novice}): "${noviceURI}"`);
        if (noviceURI && noviceURI.length > 0) {
            if (noviceURI === "ipfs://PLACEHOLDER_NOVICE_URI/metadata.json") {
                console.log("   ⚠️ Novice URI is still the placeholder set during initial deployment.");
            } else {
                console.log("   ✅ Novice URI is set.");
            }
        } else {
            console.log("   ❌ Novice URI is EMPTY. It needs to be set.");
        }
    } catch (error) {
        console.error("   ❌ Error fetching Novice URI:", error.message);
    }
    console.log("----------------------------------------------------");

    // 3. Check URI for Apprentice Stage (Stage 1)
    try {
        const apprenticeURI = await stoicAvatarNFTContract.getStageTokenURIBase(AvatarStages.Apprentice);
        console.log(`3. URI for Apprentice stage (Enum Value ${AvatarStages.Apprentice}): "${apprenticeURI}"`);
        if (apprenticeURI && apprenticeURI.length > 0) {
            console.log("   ✅ Apprentice URI is set.");
        } else {
            console.log("   ❌ Apprentice URI is EMPTY. This is likely causing the minting error for Apprentice avatars.");
        }
    } catch (error) {
        console.error("   ❌ Error fetching Apprentice URI:", error.message);
    }
    console.log("----------------------------------------------------");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });