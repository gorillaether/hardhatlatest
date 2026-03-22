// ignition/modules/DeployStoicAvatarNFT.js
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

// Helper for AvatarStages enum values (matching your Solidity enum)
// Ensure this matches the enum definition in your StoicAvatarNFT.sol
const AvatarStages = {
    Novice: 0,
    Apprentice: 1,
    Practitioner: 2,
    Scholar: 3,
    Sage: 4,
    Epictetus: 5
    // Add more if your enum has more stages
};

// --- Configuration for Metadata URIs ---
// This is the IPFS Folder CID containing your metadata JSON files and images.
const IPFS_FOLDER_CID = "bafybeifpx3pfxml4opesc56owcvs3nait7mjt36pxsh6rjbyiionn4awxq";

// Define the direct URIs to your metadata JSON files for each stage.
// For stages not yet ready, you can leave them as `null`.
// The script will only attempt to set URIs that are provided.
const STAGE_METADATA_URIS = {
    [AvatarStages.Novice]: `ipfs://${IPFS_FOLDER_CID}/novice_metadata.json`,
    [AvatarStages.Apprentice]: `ipfs://${IPFS_FOLDER_CID}/apprentice_metadata.json`,
    [AvatarStages.Practitioner]: null, // Update to e.g., `ipfs://${IPFS_FOLDER_CID}/practitioner_metadata.json` when ready
    [AvatarStages.Scholar]: null,      // Update when ready
    [AvatarStages.Sage]: null,         // Update when ready
    [AvatarStages.Epictetus]: null,    // Update when ready
};
// --- End of URI Configuration ---

module.exports = buildModule("StoicAvatarNFTModule", (m) => {
    console.log("Submitting StoicAvatarNFT contract deployment...");
    // 🔴 IMPORTANT: If your StoicAvatarNFT constructor requires arguments, add them to the array below.
    // Example: If it needs a name and symbol: m.contract("StoicAvatarNFT", ["My NFT Name", "MNFT"], {});
    const stoicAvatarNFT = m.contract("StoicAvatarNFT", [], {}); // Assuming no constructor arguments
    console.log("StoicAvatarNFT deployment transaction sent. Waiting for confirmation...");
    // The above `console.log` will appear, then Ignition waits for deployment before proceeding
    // to the `m.call` operations if they depend on `stoicAvatarNFT`.

    // After stoicAvatarNFT is deployed, its address will be available.
    // We can log it if needed, though Ignition handles the deployment object.
    // m.after(stoicAvatarNFT, () => { // This is not standard Ignition syntax for logging address directly after deployment
    //    console.log(`StoicAvatarNFT contract DEPLOYED to address: ${stoicAvatarNFT.address}`); // stoicAvatarNFT is a Future, not direct contract instance here
    // });


    console.log("\nSubmitting calls to setStageTokenURIBase for available avatar stage URIs...");

    for (const stageName in AvatarStages) {
        if (Object.hasOwnProperty.call(AvatarStages, stageName)) {
            const stageEnumValue = AvatarStages[stageName];
            const stageURI = STAGE_METADATA_URIS[stageEnumValue];

            // Check if a URI is provided and is not an empty string
            if (stageURI && stageURI.trim() !== "") {
                // This internal warning about "REPLACE_WITH_YOUR_ACTUAL_" might no longer be relevant
                // if you've replaced the placeholders directly as done above.
                // You can simplify or remove this specific warning if the above URIs are final.
                if ((stageEnumValue === AvatarStages.Novice || stageEnumValue === AvatarStages.Apprentice) &&
                    stageURI.includes("REPLACE_WITH_YOUR_ACTUAL_")) { // This check will now be false if you use the CIDs
                    console.warn(
                        `WARNING: Placeholder URI detected for stage '${stageName}'. ` +
                        `Actual URI: "${stageURI}". ` +
                        `Please update this in STAGE_METADATA_URIS before mainnet deployment if this stage is intended to be set.`
                    );
                }

                const callId = `SetURIFor${stageName}`; // Unique ID for each call within the Ignition module
                console.log(`  Submitting setStageTokenURIBase for ${stageName} (Enum: ${stageEnumValue}) to URI: ${stageURI}`);
                // This schedules a call to be made once stoicAvatarNFT is deployed.
                m.call(stoicAvatarNFT, "setStageTokenURIBase", [stageEnumValue, stageURI], {
                    id: callId,
                });
            } else {
                console.log(`  Skipping setStageTokenURIBase for ${stageName} (Enum: ${stageEnumValue}) as its URI is not provided or is empty in STAGE_METADATA_URIS.`);
            }
        }
    }
    console.log("All available setStageTokenURIBase calls have been scheduled with Ignition.");

    return { stoicAvatarNFT };
});