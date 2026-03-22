// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9; // Or your project's ^0.8.20 if using latest OZ 5.x features consistently

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StoicAvatarNFT is ERC721URIStorage, Ownable {
    uint256 private _manualNextTokenId;

    enum AvatarStage {
        Novice,
        Apprentice,
        Practitioner,
        Scholar,
        Sage,
        Epictetus
    }

    struct AvatarInfo {
        AvatarStage currentStage;
    }

    mapping(uint256 => AvatarInfo) public avatarData;
    mapping(AvatarStage => string) public stageToTokenURI_Base;

    event StageURISet(AvatarStage indexed stage, string uri);
    event AvatarMinted(address indexed owner, uint256 indexed tokenId, AvatarStage initialStage);
    event AvatarEvolved(uint256 indexed tokenId, AvatarStage newStage);
    // --- NEW DEBUG EVENT ---
    event DebugMintValues(uint256 indexed tokenId, AvatarStage stageReceived, string stageURIUsed);

    constructor() ERC721("Stoic Quest Avatar", "SQA") Ownable(msg.sender) {}

    function mintAvatar(address player, AvatarStage initialStage) public onlyOwner returns (uint256) {
        uint256 newItemId = _manualNextTokenId;
        _manualNextTokenId++;
        _safeMint(player, newItemId);

        string memory baseURIForStage = stageToTokenURI_Base[initialStage];
        // --- EMIT DEBUG EVENT ---
        emit DebugMintValues(newItemId, initialStage, baseURIForStage);

        require(bytes(baseURIForStage).length > 0, "SQA: Base URI for stage not set");
        _setTokenURI(newItemId, baseURIForStage);

        avatarData[newItemId] = AvatarInfo({
            currentStage: initialStage
        });

        emit AvatarMinted(player, newItemId, initialStage);
        return newItemId;
    }

    function evolveAvatar(uint256 tokenId, AvatarStage newStage) public {
        require(ownerOf(tokenId) == msg.sender, "SQA: Not owner or approved");
        AvatarInfo storage currentAvatarInfo = avatarData[tokenId];
        require(uint(newStage) > uint(currentAvatarInfo.currentStage), "SQA: Invalid stage progression");
        string memory baseURIForNewStage = stageToTokenURI_Base[newStage];
        require(bytes(baseURIForNewStage).length > 0, "SQA: Base URI for new stage not set");
        _setTokenURI(tokenId, baseURIForNewStage);
        currentAvatarInfo.currentStage = newStage;
        emit AvatarEvolved(tokenId, newStage);
    }

    function setStageTokenURIBase(AvatarStage stage, string memory uri) public onlyOwner {
        stageToTokenURI_Base[stage] = uri;
        emit StageURISet(stage, uri);
    }

    function getStageTokenURIBase(AvatarStage stage) public view returns (string memory) {
        return stageToTokenURI_Base[stage];
    }

    function getAvatarInfo(uint256 tokenId) public view returns (AvatarStage) {
        ownerOf(tokenId); 
        return avatarData[tokenId].currentStage;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}