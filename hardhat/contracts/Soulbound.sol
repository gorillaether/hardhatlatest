// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Soulbound is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    uint256 private _tokenIdCounter;
    
    mapping(uint256 => string) private _tokenURIs;
    
    event SoulboundMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event SoulboundBurned(uint256 indexed tokenId);
    
    constructor(
        string memory name_,
        string memory symbol_,
        address admin
    ) ERC721(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
    }
    
    function mint(address to, string memory tokenURI_) public onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        _safeMint(to, tokenId);
        _tokenURIs[tokenId] = tokenURI_;
        
        emit SoulboundMinted(to, tokenId, tokenURI_);
        
        return tokenId;
    }
    
    function burn(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _burn(tokenId);
        delete _tokenURIs[tokenId];
        
        emit SoulboundBurned(tokenId);
    }
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        return _tokenURIs[tokenId];
    }
    
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}