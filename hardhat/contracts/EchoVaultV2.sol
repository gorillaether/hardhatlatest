// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EchoVaultV2 {
    // Enums
    enum CapsuleType { TEXT, IMAGE, VIDEO, DOCUMENT }
    enum TriggerType { TIME_BASED, HEARTBEAT }
    enum SubscriptionTier { FREE, PRO, PREMIUM }

    // Structs
    struct Capsule {
        uint256 id;
        address creator;
        CapsuleType capsuleType;
        TriggerType triggerType;
        uint256 unlockTime;
        uint256 createdAt;
        address[] recipients;
        bool isUnlocked;
        bool isCancelled;
        bool isEmergencyUnlocked;
        // Dead Man's Switch fields
        uint256 heartbeatInterval; // in seconds
        uint256 lastCheckIn;
    }

    struct UnlockStage {
        string ipfsHash;
        string encryptedKeys;
    }

    // State variables
    mapping(uint256 => Capsule) public capsules;
    mapping(uint256 => UnlockStage[]) public capsuleStages;
    mapping(uint256 => string) public capsuleMetadata;
    mapping(address => uint256[]) public userCapsules;
    mapping(address => SubscriptionTier) public userTiers;
    
    uint256 public totalCapsules; // NEW: Track total capsules
    uint256 public constant MAX_FREE_CAPSULES = 1;
    uint256 public constant MAX_PRO_CAPSULES = 10;
    uint256 public constant MAX_PREMIUM_CAPSULES = 100;

    // Pricing (in wei)
    mapping(CapsuleType => uint256) public creationFees;

    address public owner;

    // Events
    event CapsuleCreated(
        uint256 indexed capsuleId,
        address indexed creator,
        CapsuleType capsuleType,
        TriggerType triggerType,
        uint256 unlockTime,
        uint256 heartbeatInterval
    );
    
    event CapsuleUnlocked(
        uint256 indexed capsuleId,
        address indexed unlocker,
        bool isEmergency
    );
    
    event HeartbeatCheckedIn(
        uint256 indexed capsuleId,
        address indexed checker,
        uint256 timestamp
    );

    event CapsuleCancelled(uint256 indexed capsuleId);
    event EmergencyUnlock(uint256 indexed capsuleId, address indexed creator);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    modifier onlyCreator(uint256 _capsuleId) {
        require(capsules[_capsuleId].creator == msg.sender, "Not the creator");
        _;
    }

    constructor() {
        owner = msg.sender;

        // Set default creation fees
        creationFees[CapsuleType.TEXT] = 0.1 ether;
        creationFees[CapsuleType.IMAGE] = 0.2 ether;
        creationFees[CapsuleType.VIDEO] = 0.5 ether;
        creationFees[CapsuleType.DOCUMENT] = 0.15 ether;
    }

    function createCapsule(
        CapsuleType _capsuleType,
        TriggerType _triggerType,
        uint256 _unlockTime,
        string memory _encryptedKeys,
        string memory _ipfsHash,
        address[] memory _recipients,
        string memory _metadata,
        uint256 _heartbeatInterval // NEW: 0 for time-based, >0 for heartbeat
    ) external payable returns (uint256) {
        require(_recipients.length > 0, "At least one recipient required");
        require(msg.value >= creationFees[_capsuleType], "Insufficient creation fee");

        // Check tier limits
        SubscriptionTier tier = userTiers[msg.sender];
        uint256 userCapsuleCount = userCapsules[msg.sender].length;

        if (tier == SubscriptionTier.FREE) {
            require(userCapsuleCount < MAX_FREE_CAPSULES, "Capsule limit reached");
        } else if (tier == SubscriptionTier.PRO) {
            require(userCapsuleCount < MAX_PRO_CAPSULES, "Capsule limit reached");
        } else if (tier == SubscriptionTier.PREMIUM) {
            require(userCapsuleCount < MAX_PREMIUM_CAPSULES, "Capsule limit reached");
        }

        // Validate trigger type parameters
        if (_triggerType == TriggerType.TIME_BASED) {
            require(_unlockTime > block.timestamp, "Unlock time must be in future");
            require(_heartbeatInterval == 0, "Heartbeat interval must be 0 for time-based");
        } else if (_triggerType == TriggerType.HEARTBEAT) {
            require(_heartbeatInterval > 0, "Heartbeat interval required");
            require(_heartbeatInterval >= 1 days, "Heartbeat interval too short");
        }

        totalCapsules++; // NEW: Increment counter
        uint256 capsuleId = totalCapsules;

        Capsule memory newCapsule = Capsule({
            id: capsuleId,
            creator: msg.sender,
            capsuleType: _capsuleType,
            triggerType: _triggerType,
            unlockTime: _unlockTime,
            createdAt: block.timestamp,
            recipients: _recipients,
            isUnlocked: false,
            isCancelled: false,
            isEmergencyUnlocked: false,
            heartbeatInterval: _heartbeatInterval,
            lastCheckIn: block.timestamp
        });

        capsules[capsuleId] = newCapsule;
        userCapsules[msg.sender].push(capsuleId);

        // Store unlock stage
        UnlockStage memory stage = UnlockStage({
            ipfsHash: _ipfsHash,
            encryptedKeys: _encryptedKeys
        });
        capsuleStages[capsuleId].push(stage);

        capsuleMetadata[capsuleId] = _metadata;

        emit CapsuleCreated(
            capsuleId,
            msg.sender,
            _capsuleType,
            _triggerType,
            _unlockTime,
            _heartbeatInterval
        );

        return capsuleId;
    }

    // NEW: Check in for heartbeat capsules
    function checkIn(uint256 _capsuleId) external onlyCreator(_capsuleId) {
        Capsule storage capsule = capsules[_capsuleId];
        require(!capsule.isCancelled, "Capsule is cancelled");
        require(!capsule.isUnlocked, "Capsule already unlocked");
        require(capsule.triggerType == TriggerType.HEARTBEAT, "Not a heartbeat capsule");

        capsule.lastCheckIn = block.timestamp;

        emit HeartbeatCheckedIn(_capsuleId, msg.sender, block.timestamp);
    }

    // NEW: Emergency unlock by creator
    function emergencyUnlock(uint256 _capsuleId) external onlyCreator(_capsuleId) {
        Capsule storage capsule = capsules[_capsuleId];
        require(!capsule.isCancelled, "Capsule is cancelled");
        require(!capsule.isUnlocked, "Already unlocked");

        capsule.isUnlocked = true;
        capsule.isEmergencyUnlocked = true;

        emit EmergencyUnlock(_capsuleId, msg.sender);
        emit CapsuleUnlocked(_capsuleId, msg.sender, true);
    }

    function isUnlocked(uint256 _capsuleId) public view returns (bool) {
        Capsule memory capsule = capsules[_capsuleId];
        
        if (capsule.isCancelled) return false;
        if (capsule.isUnlocked) return true;

        if (capsule.triggerType == TriggerType.TIME_BASED) {
            return block.timestamp >= capsule.unlockTime;
        } else if (capsule.triggerType == TriggerType.HEARTBEAT) {
            // Check if heartbeat expired
            return block.timestamp >= capsule.lastCheckIn + capsule.heartbeatInterval;
        }

        return false;
    }
    function getCapsule(uint256 _capsuleId) external view returns (
        uint256,
        address,
        CapsuleType,
        TriggerType,
        uint256,
        uint256,
        address[] memory,
        bool,
        bool,
        bool,
        uint256,
        uint256
    ) {
        Capsule memory c = capsules[_capsuleId];
        return (
            c.id,
            c.creator,
            c.capsuleType,
            c.triggerType,
            c.unlockTime,
            c.createdAt,
            c.recipients,
            c.isUnlocked,
            c.isCancelled,
            c.isEmergencyUnlocked,
            c.heartbeatInterval,
            c.lastCheckIn
        );
    }

    function getUnlockedStages(uint256 _capsuleId) external view returns (UnlockStage[] memory) {
        require(isUnlocked(_capsuleId), "Capsule not unlocked");
        return capsuleStages[_capsuleId];
    }

    function getUserCapsules(address _user) external view returns (uint256[] memory) {
        return userCapsules[_user];
    }

    function cancelCapsule(uint256 _capsuleId) external onlyCreator(_capsuleId) {
        Capsule storage capsule = capsules[_capsuleId];
        require(!capsule.isUnlocked, "Cannot cancel unlocked capsule");
        require(!capsule.isCancelled, "Already cancelled");

        capsule.isCancelled = true;
        emit CapsuleCancelled(_capsuleId);
    }

    // Admin functions
    function updateUserTier(address _user, SubscriptionTier _tier) external onlyOwner {
        userTiers[_user] = _tier;
    }

    function updatePricing(CapsuleType _type, uint256 _fee) external onlyOwner {
        creationFees[_type] = _fee;
    }

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {}
}

