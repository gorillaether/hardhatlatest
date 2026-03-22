const { expect } = require("chai");
const { ethers } = require("hardhat");

// Helper for AvatarStages (0 for Novice, etc.)
// This matches the enum order in your Solidity contract.
const AvatarStages = {
    Novice: 0,
    Apprentice: 1,
    Practitioner: 2,
    Scholar: 3,
    Sage: 4,
    Epictetus: 5
};

describe("StoicAvatarNFT Contract", function () {
    let StoicAvatarNFTFactory;
    let stoicAvatarNFT;
    let owner;
    let player1;
    let player2;

    // This top-level beforeEach deploys a fresh contract for each top-level describe
    // or for each 'it' if there's only one top-level describe.
    // For nested describes, if the inner describe also has a beforeEach,
    // this one runs first, then the inner one.
    beforeEach(async function () {
        StoicAvatarNFTFactory = await ethers.getContractFactory("StoicAvatarNFT");
        [owner, player1, player2] = await ethers.getSigners();
        stoicAvatarNFT = await StoicAvatarNFTFactory.deploy();
    });

    describe("Deployment", function () {
        it("Should have the correct name and symbol", async function () {
            expect(await stoicAvatarNFT.name()).to.equal("Stoic Quest Avatar");
            expect(await stoicAvatarNFT.symbol()).to.equal("SQA");
        });

        it("Should set the deployer as the owner", async function () {
            expect(await stoicAvatarNFT.owner()).to.equal(owner.address);
        });
    });

    describe("Admin Functions: setStageTokenURIBase", function () {
        it("Owner should be able to set a stage token URI base", async function () {
            const noviceStage = AvatarStages.Novice;
            const testURI = "ipfs://novice_uri_base/";
            await stoicAvatarNFT.connect(owner).setStageTokenURIBase(noviceStage, testURI);
            expect(await stoicAvatarNFT.stageToTokenURI_Base(noviceStage)).to.equal(testURI);
        });

        it("Non-owner should not be able to set a stage token URI base", async function () {
            const noviceStage = AvatarStages.Novice;
            const testURI = "ipfs://another_uri/";
            await expect(stoicAvatarNFT.connect(player1).setStageTokenURIBase(noviceStage, testURI))
                .to.be.revertedWithCustomError(stoicAvatarNFT, "OwnableUnauthorizedAccount")
                .withArgs(player1.address);
        });

        it("Should allow setting URIs for multiple stages", async function () {
            const noviceStage = AvatarStages.Novice;
            const apprenticeStage = AvatarStages.Apprentice;
            const noviceURI = "ipfs://novice/";
            const apprenticeURI = "ipfs://apprentice/";

            await stoicAvatarNFT.connect(owner).setStageTokenURIBase(noviceStage, noviceURI);
            await stoicAvatarNFT.connect(owner).setStageTokenURIBase(apprenticeStage, apprenticeURI);

            expect(await stoicAvatarNFT.stageToTokenURI_Base(noviceStage)).to.equal(noviceURI);
            expect(await stoicAvatarNFT.stageToTokenURI_Base(apprenticeStage)).to.equal(apprenticeURI);
        });
    });

    describe("Minting (`mintAvatar`)", function () {
        const noviceStage = AvatarStages.Novice;
        const noviceURI = "ipfs://novice_metadata.json";

        // This beforeEach is specific to the "Minting" describe block.
        // It runs after the top-level beforeEach.
        beforeEach(async function () {
            await stoicAvatarNFT.connect(owner).setStageTokenURIBase(noviceStage, noviceURI);
        });

        it("Owner should be able to mint a new avatar to a player", async function () {
            await expect(stoicAvatarNFT.connect(owner).mintAvatar(player1.address, noviceStage))
                .to.emit(stoicAvatarNFT, "AvatarMinted")
                .withArgs(player1.address, 0, noviceStage); // TokenId 0 for the first mint in this fresh contract

            expect(await stoicAvatarNFT.ownerOf(0)).to.equal(player1.address);
            expect(await stoicAvatarNFT.balanceOf(player1.address)).to.equal(1);

            const currentStageValue = await stoicAvatarNFT.avatarData(0);
            expect(currentStageValue).to.equal(noviceStage);

            expect(await stoicAvatarNFT.tokenURI(0)).to.equal(noviceURI);
        });

        it("Should increment token IDs for subsequent mints", async function () {
            // First mint (tokenId 0)
            await stoicAvatarNFT.connect(owner).mintAvatar(player1.address, noviceStage);
            // Second mint (tokenId 1)
            await expect(stoicAvatarNFT.connect(owner).mintAvatar(player2.address, noviceStage))
                .to.emit(stoicAvatarNFT, "AvatarMinted")
                .withArgs(player2.address, 1, noviceStage);

            expect(await stoicAvatarNFT.ownerOf(1)).to.equal(player2.address);
        });

        it("Non-owner should not be able to mint an avatar", async function () {
            await expect(stoicAvatarNFT.connect(player1).mintAvatar(player1.address, noviceStage))
                .to.be.revertedWithCustomError(stoicAvatarNFT, "OwnableUnauthorizedAccount")
                .withArgs(player1.address);
        });

        it("Should fail to mint if the stage URI base is not set for the given stage", async function () {
            const apprenticeStage = AvatarStages.Apprentice;
            await expect(stoicAvatarNFT.connect(owner).mintAvatar(player1.address, apprenticeStage))
                .to.be.revertedWith("SQA: Base URI for stage not set");
        });
    });

    describe("Avatar Evolution (`evolveAvatar`)", function () {
        const noviceStage = AvatarStages.Novice;
        const apprenticeStage = AvatarStages.Apprentice;
        const practitionerStage = AvatarStages.Practitioner;

        const noviceURI = "ipfs://novice_metadata.json";
        const apprenticeURI = "ipfs://apprentice_metadata.json";
        const practitionerURI = "ipfs://practitioner_metadata.json";

        let mintedTokenId;

        // This beforeEach is specific to the "Avatar Evolution" describe block.
        // It runs after the top-level beforeEach.
        beforeEach(async function () {
            // Owner sets up the URIs for stages we'll use in these tests
            await stoicAvatarNFT.connect(owner).setStageTokenURIBase(noviceStage, noviceURI);
            await stoicAvatarNFT.connect(owner).setStageTokenURIBase(apprenticeStage, apprenticeURI);
            await stoicAvatarNFT.connect(owner).setStageTokenURIBase(practitionerStage, practitionerURI);

            // Owner mints a Novice avatar to player1.
            // Since _manualNextTokenId starts at 0 in a fresh contract instance (from the top-level beforeEach),
            // the first minted token ID here will be 0.
            const tx = await stoicAvatarNFT.connect(owner).mintAvatar(player1.address, noviceStage);
            await tx.wait(); // Ensure minting transaction is complete
            
            mintedTokenId = 0; // Directly assign, as it's the first token minted in this setup
        });

        it("Token owner should be able to evolve their avatar to a valid next stage", async function () {
            await expect(stoicAvatarNFT.connect(player1).evolveAvatar(mintedTokenId, apprenticeStage))
                .to.emit(stoicAvatarNFT, "AvatarEvolved")
                .withArgs(mintedTokenId, apprenticeStage);

            const newAvatarInfo = await stoicAvatarNFT.avatarData(mintedTokenId);
            expect(newAvatarInfo).to.equal(apprenticeStage);
            expect(await stoicAvatarNFT.tokenURI(mintedTokenId)).to.equal(apprenticeURI);
        });

        it("Should allow further evolution to subsequent valid stages", async function () {
            // First evolution (Novice -> Apprentice)
            await stoicAvatarNFT.connect(player1).evolveAvatar(mintedTokenId, apprenticeStage);
            
            // Second evolution (Apprentice -> Practitioner)
            await expect(stoicAvatarNFT.connect(player1).evolveAvatar(mintedTokenId, practitionerStage))
                .to.emit(stoicAvatarNFT, "AvatarEvolved")
                .withArgs(mintedTokenId, practitionerStage);

            const finalAvatarInfo = await stoicAvatarNFT.avatarData(mintedTokenId);
            expect(finalAvatarInfo).to.equal(practitionerStage);
            expect(await stoicAvatarNFT.tokenURI(mintedTokenId)).to.equal(practitionerURI);
        });

        it("Should NOT allow evolution if the caller is not the token owner", async function () {
            // player2 (not owner of mintedTokenId) tries to evolve player1's token
            await expect(stoicAvatarNFT.connect(player2).evolveAvatar(mintedTokenId, apprenticeStage))
                .to.be.revertedWith("SQA: Not owner or approved"); 
        });

        it("Should NOT allow evolution to the same stage", async function () {
            await expect(stoicAvatarNFT.connect(player1).evolveAvatar(mintedTokenId, noviceStage)) // Trying to evolve to current stage (Novice)
                .to.be.revertedWith("SQA: Invalid stage progression");
        });

        it("Should NOT allow evolution to a lower stage (regression)", async function () {
            // First evolve to Apprentice
            await stoicAvatarNFT.connect(player1).evolveAvatar(mintedTokenId, apprenticeStage);
            // Then try to evolve back to Novice
            await expect(stoicAvatarNFT.connect(player1).evolveAvatar(mintedTokenId, noviceStage))
                .to.be.revertedWith("SQA: Invalid stage progression");
        });

        it("Should fail to evolve if the target stage URI base is not set", async function () {
            const sageStage = AvatarStages.Sage; // URI for this stage is NOT set in the beforeEach for this suite
            await expect(stoicAvatarNFT.connect(player1).evolveAvatar(mintedTokenId, sageStage))
                .to.be.revertedWith("SQA: Base URI for new stage not set");
        });
    });

});