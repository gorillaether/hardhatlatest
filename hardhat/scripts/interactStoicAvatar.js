// scripts/interactStoicAvatar.js
const { ethers } = require("hardhat");

// Helper for AvatarStages enum values
const AvatarStages = {
    Novice: 0,
    Apprentice: 1,
    Practitioner: 2, // Added for completeness if you expand tests
    Scholar: 3,
    Sage: 4,
    Epictetus: 5
};

// Helper function to get stage name from enum value
const getStageName = (stageValueAsNumber) => {
    // Now expects stageValueAsNumber to be a primitive number
    return Object.keys(AvatarStages).find(key => AvatarStages[key] === stageValueAsNumber);
};

async function main() {
    // --- CONFIGURATION ---
    const contractAddress = process.env.CONTRACT_ADDRESS;
    const playerAddress = process.env.PLAYER_ADDRESS; 

    if (!contractAddress || !playerAddress) {
        console.error("Please set CONTRACT_ADDRESS and PLAYER_ADDRESS environment variables.");
        console.log("Example: CONTRACT_ADDRESS=0x... PLAYER_ADDRESS=0x... npx hardhat run scripts/interactStoicAvatar.js --network localhost");
        process.exit(1);
    }

    const [ownerSigner] = await ethers.getSigners(); 

    console.log(`Interacting with StoicAvatarNFT at: ${contractAddress}`);
    console.log(`Using owner account (for minting): ${ownerSigner.address}`);
    console.log(`Target player account for NFT: ${playerAddress}`);

    const StoicAvatarNFTFactory = await ethers.getContractFactory("StoicAvatarNFT");
    const stoicAvatarNFT = StoicAvatarNFTFactory.attach(contractAddress);

    // --- 1. Mint a Novice Avatar ---
    console.log("\n--- Minting Novice Avatar ---");
    const initialStageToMint = AvatarStages.Novice;
    const mintTx = await stoicAvatarNFT.connect(ownerSigner).mintAvatar(playerAddress, initialStageToMint);
    console.log("Mint transaction sent, waiting for confirmation...", mintTx.hash);
    
    await mintTx.wait(); 
    console.log("Mint transaction mined.");

    let mintedTokenId = 0; 
    console.log(`✅ Avatar Minted (assumed)! Token ID: ${mintedTokenId}, Initial Stage Enum Value (from script): ${initialStageToMint}`);
    
    let stageValueFromContract = await stoicAvatarNFT.getAvatarInfo(mintedTokenId);
    // Ensure stageValueFromContract is a JS number before passing to getStageName
    let numericStageValue = typeof stageValueFromContract.toNumber === 'function' 
                            ? stageValueFromContract.toNumber() 
                            : Number(stageValueFromContract);

    let currentTokenURI = await stoicAvatarNFT.tokenURI(mintedTokenId);
    console.log(`Novice Avatar (ID ${mintedTokenId}) Info:`);
    console.log(`  Current Stage Name: ${getStageName(numericStageValue)} (Enum value from contract: ${numericStageValue})`);
    console.log(`  Token URI: ${currentTokenURI}`);

    // --- 2. Evolve the Avatar to Apprentice ---
    console.log("\n--- Evolving Avatar to Apprentice ---");
    
    let playerSigner;
    const signers = await ethers.getSigners();
    playerSigner = signers.find(s => s.address.toLowerCase() === playerAddress.toLowerCase());

    if (!playerSigner) {
        if (playerAddress.toLowerCase() === ownerSigner.address.toLowerCase()) {
            console.log("Player address is the same as owner/deployer. Using ownerSigner for evolution.");
            playerSigner = ownerSigner;
        } else {
            try {
                playerSigner = await ethers.getSigner(playerAddress);
            } catch (e) {
                 console.error(`Failed to get signer for ${playerAddress}. Ensure this address is available to Hardhat.`);
                 process.exit(1);
            }
        }
    }
    
    const stageToEvolveTo = AvatarStages.Apprentice;
    const evolveTx = await stoicAvatarNFT.connect(playerSigner).evolveAvatar(mintedTokenId, stageToEvolveTo);
    console.log("Evolve transaction sent, waiting for confirmation...", evolveTx.hash);
    await evolveTx.wait();
    console.log(`✅ Avatar Evolved to ${getStageName(stageToEvolveTo)}!`);

    stageValueFromContract = await stoicAvatarNFT.getAvatarInfo(mintedTokenId);
    numericStageValue = typeof stageValueFromContract.toNumber === 'function' 
                        ? stageValueFromContract.toNumber() 
                        : Number(stageValueFromContract);
    currentTokenURI = await stoicAvatarNFT.tokenURI(mintedTokenId);
    console.log(`${getStageName(stageToEvolveTo)} Avatar (ID ${mintedTokenId}) Info:`); // Display expected stage name
    console.log(`  Current Stage Name: ${getStageName(numericStageValue)} (Enum value from contract: ${numericStageValue})`);
    console.log(`  Token URI: ${currentTokenURI}`);

    console.log("\nInteraction script finished successfully!");
}

main().then(() => process.exit(0)).catch((error) => {
    console.error("❌ Error during interaction script:", error);
    process.exit(1);
});