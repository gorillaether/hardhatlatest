// scripts/setStoicQuestStageURI.js
require("dotenv").config(); // If you use a .env file for other things like PINATA_JWT
const { ethers } = require("hardhat");

// Helper for AvatarStages enum values (matching your Solidity enum)
const AvatarStages = {
    Novice: 0,
    Apprentice: 1,
    Practitioner: 2,
    Scholar: 3,
    Sage: 4,
    Epictetus: 5
    // Add more if your enum has more
};

async function main() {
    const contractAddress = process.env.CONTRACT_ADDRESS;
    const stageName = process.env.STAGE_NAME;
    const stageURI = process.env.STAGE_URI;

    if (!contractAddress || !stageName || !stageURI) {
        console.error(
            "ERROR: Please provide CONTRACT_ADDRESS, STAGE_NAME, and STAGE_URI as environment variables."
        );
        console.log(
            "Example: CONTRACT_ADDRESS=0x... STAGE_NAME=Novice STAGE_URI=ipfs://... npx hardhat run scripts/setStoicQuestStageURI.js --network <your_network>"
        );
        console.log(
            "Available stage names:",
            Object.keys(AvatarStages).join(", ")
        );
        process.exit(1);
    }

    const stageEnumValue = AvatarStages[stageName];
    if (stageEnumValue === undefined) {
        console.error(
            `ERROR: Invalid stage name "${stageName}". Available stages: ${Object.keys(
                AvatarStages
            ).join(", ")}`
        );
        process.exit(1);
    }

    console.log(`Attempting to set URI for stage: ${stageName} (Enum value: ${stageEnumValue})`);
    console.log(`Contract Address: ${contractAddress}`);
    console.log(`New URI: ${stageURI}`);

    // Get the signer (account that will send the transaction)
    const [signer] = await ethers.getSigners();
    console.log(`Transaction will be sent from: ${signer.address}`);

    // Get the contract factory for StoicAvatarNFT
    const StoicAvatarNFTFactory = await ethers.getContractFactory("StoicAvatarNFT");
    // Attach to the deployed instance
    const stoicAvatarNFTContract = StoicAvatarNFTFactory.attach(contractAddress);

    // Call the setStageTokenURIBase function
    console.log(`Calling setStageTokenURIBase(${stageEnumValue}, "${stageURI}")...`);
    const tx = await stoicAvatarNFTContract.connect(signer).setStageTokenURIBase(stageEnumValue, stageURI);

    console.log("Transaction sent! Waiting for confirmation...");
    console.log("Transaction hash:", tx.hash);
    const receipt = await tx.wait(); // Wait for the transaction to be mined and get the receipt
    console.log(`✅ Stage URI for ${stageName} set successfully (Transaction mined)!`);

    // --- Check for the event in the receipt ---
    let eventFound = false;
    if (receipt.events) { // Ensure receipt and receipt.events exist
        for (const event of receipt.events) {
            if (event.event === "StageURISet") {
                console.log("🔍 Event 'StageURISet' found:");
                console.log("  Stage (Enum Value):", event.args.stage.toString()); // Enums might be BigNumberish, convert to string
                console.log("  URI Set in event:", event.args.uri);
                eventFound = true;
                break;
            }
        }
    }
    if (!eventFound) {
        console.log("⚠️ Event 'StageURISet' not found in transaction receipt.");
    }

    // --- MODIFIED VERIFICATION STEP: Call the new explicit getter ---
    try {
        console.log(`Verifying URI by calling getStageTokenURIBase(${stageEnumValue})...`);
        const retrievedURI = await stoicAvatarNFTContract.getStageTokenURIBase(stageEnumValue); // Call the new explicit getter
        console.log(`Retrieved URI for ${stageName} (stage ${stageEnumValue}) via explicit getter: ${retrievedURI}`);
        if (retrievedURI === stageURI) {
            console.log("Verification successful!");
        } else {
            console.error(`❌ Verification FAILED. Set URI: "${stageURI}", Retrieved URI: "${retrievedURI}"`);
        }
    } catch (e) {
        console.error("❌ Error during verification via explicit getter:", e.message);
        if (e.data) { // Ethers v6 often includes more data in e.data for reverts
            console.error("  Error data:", e.data);
        }
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Error in script execution:", error);
        process.exit(1);
    });