// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/cryptography/Counters.sol"; // ✅ REMOVED

contract SubscriptionNFT is ERC721, ERC721URIStorage, Ownable {
    // using Counters for Counters.Counter; // ✅ REMOVED
    // Counters.Counter private _tokenIds; // ✅ REPLACED
    uint256 private _nextTokenId = 1; // ✅ ADDED (We start at 1)

    // --- NEW: Struct to hold subscription data ---
    struct Subscription {
        address creator;
        uint256 expiryTimestamp;
    }

    // --- NEW: Mapping from a Token ID to its subscription data ---
    mapping(uint256 => Subscription) public subscriptionData;

    // --- NEW: Mapping to find a user's active token for a specific creator ---
    // mapping(address subscriber => mapping(address creator => uint256 tokenId))
    mapping(address => mapping(address => uint256)) public activeSubscriptionToken;

    // --- NEW: Events to log when subscriptions are created or renewed ---
    event SubscriptionMinted(
        address indexed subscriber,
        address indexed creator,
        uint256 indexed tokenId,
        uint256 expiryTimestamp
    );
    
    event SubscriptionRenewed(
        uint256 indexed tokenId,
        uint256 newExpiryTimestamp
    );

    constructor(address initialOwner)
        ERC721("DID Subscription", "DIDSUB")
        Ownable(initialOwner)
    {}

    // --- UPDATED: mintSubscription Function ---
    function mintSubscription(
        address subscriber,
        address creator,
        string memory _tokenURI
    ) public onlyOwner {
        uint256 existingTokenId = activeSubscriptionToken[subscriber][creator];
        uint256 expiry = block.timestamp + 30 days;

        if (existingTokenId != 0) {
            subscriptionData[existingTokenId].expiryTimestamp = expiry;
            emit SubscriptionRenewed(existingTokenId, expiry);
            return;
        }

        // ✅ REPLACED COUNTER LOGIC
        uint256 newTokenId = _nextTokenId;
        _nextTokenId++; // Increment for the next mint

        _safeMint(subscriber, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);

        subscriptionData[newTokenId] = Subscription(creator, expiry);
        activeSubscriptionToken[subscriber][creator] = newTokenId;

        emit SubscriptionMinted(subscriber, creator, newTokenId, expiry);
    }

    // --- NEW: renewSubscription Function ---
    function renewSubscription(
        address subscriber,
        address creator
    ) public onlyOwner {
        uint256 tokenId = activeSubscriptionToken[subscriber][creator];
        require(tokenId != 0, "No active subscription found for this user.");

        uint256 currentExpiry = subscriptionData[tokenId].expiryTimestamp;
        uint256 newExpiry;

        if (currentExpiry < block.timestamp) {
            newExpiry = block.timestamp + 30 days;
        } else {
            newExpiry = currentExpiry + 30 days;
        }

        subscriptionData[tokenId].expiryTimestamp = newExpiry;
        emit SubscriptionRenewed(tokenId, newExpiry);
    }

    // --- UPDATED: hasValidSubscription Function ---
    function hasValidSubscription(
        address subscriber,
        address creator,
        uint256 tier
    ) public view returns (bool) {
        uint256 tokenId = activeSubscriptionToken[subscriber][creator];
        
        if (tokenId == 0) {
            return false;
        }
        
        return subscriptionData[tokenId].expiryTimestamp >= block.timestamp;
    }

    // Required by ERC721URIStorage
    function _baseURI() internal pure override returns (string memory) {
        return "";
    }

    // Required by ERC721URIStorage
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        _requireOwned(tokenId);
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}