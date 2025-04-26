// SPDX-License-Identifier: MIT
// Updated contract for OpenZeppelin v5.x compatibility (or if Counters.sol is unavailable)
// Includes tokenURI override to append .json
pragma solidity ^0.8.9; // Ensure this version is compatible with your OZ install (0.8.20+ recommended for OZ v5)

import "@openzeppelin/contracts/utils/Strings.sol"; // Needed for tokenURI override
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; // Assuming Ownable is still desired and correctly installed
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol"; // Check if path changed in v5 if compile fails here later

/**
 * @title Market Mood NFT (No Counters.sol)
 * @dev ERC721 contract for the Market Mood collection.
 * - Minting restricted to the owner.
 * - Token IDs auto-increment using an internal variable.
 * - Supports ERC2981 royalties (5%).
 * - Metadata stored on IPFS via baseURI, resolves to baseURI/{tokenId}.json.
 */
contract MarketMood is ERC721, ERC721Burnable, Ownable, ERC2981 {
    // Use a simple uint256 for tracking the next token ID
    uint256 private _nextTokenId; // Will start at 0 by default

    string private _contractBaseURI; // Store the base URI for metadata

    // Royalty percentage (500 = 5%)
    uint96 private constant _ROYALTY_FEE_NUMERATOR = 500; // 500 / 10000 = 5%

    /**
     * @dev Sets up the contract, initializes name, symbol, owner, and default royalty.
     * Assumes OpenZeppelin v5 Ownable pattern.
     */
     constructor(address initialOwner) ERC721("Market Mood", "MMOOD") Ownable(initialOwner) {
        // Set the default royalty information for the entire collection
        // The royalty receiver is the contract deployer (initial owner)
        _setDefaultRoyalty(initialOwner, _ROYALTY_FEE_NUMERATOR);
    }

    /**
     * @dev Mints a new NFT to the specified address. Only callable by the contract owner.
     * Assigns the next available token ID using the internal counter.
     * @param to The address to mint the NFT to.
     * @return The ID of the minted token.
     */
    function safeMint(address to) public onlyOwner returns (uint256) {
        // Use the internal _nextTokenId state variable
        uint256 tokenId = _nextTokenId;
        _nextTokenId++; // Increment the counter for the next mint
        _safeMint(to, tokenId);
        return tokenId;
    }

    /**
     * @dev Sets the base URI for all token IDs. Only callable by the contract owner.
     * The base URI should point to a directory on IPFS ending with a '/'.
     * Example: "ipfs://YOUR_CID_HERE/"
     * @param newBaseURI The new base URI string.
     */
    function setBaseURI(string memory newBaseURI) public onlyOwner {
        _contractBaseURI = newBaseURI;
    }

    /**
     * @dev Returns the base URI set for the contract. Used by tokenURI().
     */
    function _baseURI() internal view override returns (string memory) {
        return _contractBaseURI;
    }

    // --- ADDED FUNCTION ---
    /**
     * @dev Overrides tokenURI to append ".json" to the token ID, forming the full metadata URI.
     */
    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
    // Instead of checking _exists directly, call ownerOf.
    // ownerOf(tokenId) will revert if the token doesn't exist, achieving the necessary check.
    ownerOf(tokenId);

    // If ownerOf did not revert, the token exists, proceed:
    string memory baseURI = _baseURI();
    return bytes(baseURI).length > 0
        ? string(abi.encodePacked(baseURI, Strings.toString(tokenId), ".json"))
        : "";
}
    // --- END OF ADDED FUNCTION ---

    /**
     * @dev Overrides the public burn function to also clear potential token-specific royalties.
     * Called by the public burn function in ERC721Burnable.
     */
    function burn(uint256 tokenId) public override(ERC721Burnable) {
        // First, execute the original burn logic from ERC721Burnable
        super.burn(tokenId);
        // Then, reset any potential token-specific royalty info
        _resetTokenRoyalty(tokenId);
    }


    /**
     * @dev See {IERC165-supportsInterface}. Includes support for ERC2981.
     * Make sure paths for imported interfaces/contracts are correct for your OZ version.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981) // May need adjustment based on specific OZ v5 structure if ERC2981 changed location/inheritance significantly
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}