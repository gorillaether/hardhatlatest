// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title EchoVault - Premium Time Capsule System
 * @notice Advanced time-locked message system with Web 2.5 support:
 *         - Platform wallet can create capsules for users (gasless UX)
 *         - Dead man's switch monitoring
 *         - Multi-recipient capsules
 *         - Progressive unlock (multiple stages)
 *         - Multiple media types (text, image, video, document)
 *         - Backup guardians
 * @dev Version 2.1 - Web 2.5 Support
 */
contract EchoVault is Ownable, ReentrancyGuard, Pausable {
    
    // ============================================
    // ENUMS & STRUCTS
    // ============================================
    
    enum CapsuleType { TEXT, IMAGE, VIDEO, DOCUMENT, MULTI }
    enum CapsuleStatus { ACTIVE, UNLOCKED, CANCELLED, TRIGGERED }
    enum TriggerType { TIME_BASED, DEAD_MANS_SWITCH, MANUAL }
    
    struct UnlockStage {
        uint256 unlockTime;           // When this stage unlocks
        string encryptedKeys;         // Keys for this stage's content
        string ipfsHash;              // IPFS hash for this stage
        bool isUnlocked;              // Whether stage has been unlocked
    }
    
    struct Capsule {
        uint256 id;
        address creator;              // Actual owner (not necessarily msg.sender)
        CapsuleType capsuleType;
        CapsuleStatus status;
        TriggerType triggerType;
        
        // Time-based unlock
        uint256 primaryUnlockTime;
        
        // Dead man's switch
        uint256 lastCheckIn;
        uint256 checkInInterval;      // How often creator must check in (seconds)
        uint256 gracePeriod;          // Extra time before auto-unlock
        
        // Recipients
        address[] recipients;
        mapping(address => bool) isRecipient;
        
        // Backup guardians (can help unlock if primary method fails)
        address[] guardians;
        mapping(address => bool) isGuardian;
        uint256 guardiansRequired;    // How many guardian approvals needed
        mapping(address => bool) guardianApproved;
        uint256 guardiansApprovedCount;
        
        // Progressive unlock (multiple stages)
        UnlockStage[] stages;
        
        // Metadata
        uint256 createdAt;
        uint256 maxStorageSize;       // In bytes
        string metadata;              // JSON metadata (title, description, etc.)
        
        // Premium features
        bool emailNotification;
        bool multipleRecipients;
        bool progressiveUnlock;
        bool hasDeadMansSwitch;
        
        // Platform creation tracking
        bool createdByPlatform;       // Whether platform created this for user
    }
    
    struct SubscriptionTier {
        string name;
        uint256 pricePerYear;         // In wei
        uint256 maxCapsules;
        uint256 maxStoragePerCapsule; // In bytes
        bool allowsVideo;
        bool allowsDeadMansSwitch;
        bool allowsMultiRecipient;
        bool allowsProgressiveUnlock;
    }
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    // Platform wallet (can create capsules for users)
    address public platformWallet;
    
    // Capsule tracking
    uint256 public capsuleCounter;
    mapping(uint256 => Capsule) public capsules;
    mapping(address => uint256[]) public userCapsules;
    
    // Subscription system
    mapping(address => SubscriptionTier) public userSubscriptions;
    mapping(address => uint256) public subscriptionExpiry;
    
    // Pricing
    mapping(CapsuleType => uint256) public creationFees;
    uint256 public deadMansSwitchFeePerYear;
    uint256 public multiRecipientFee;
    uint256 public progressiveUnlockFee;
    
    // Platform
    address public treasury;
    uint256 public platformFeePercent; // Basis points (100 = 1%)
    
    // Subscription tiers
    mapping(string => SubscriptionTier) public tiers;
    
    // ============================================
    // EVENTS
    // ============================================
    
    event CapsuleCreated(
        uint256 indexed capsuleId,
        address indexed creator,
        CapsuleType capsuleType,
        uint256 unlockTime,
        bool createdByPlatform
    );
    
    event CapsuleUnlocked(
        uint256 indexed capsuleId,
        address indexed unlockedBy,
        uint256 stageNumber
    );
    
    event CheckInPerformed(
        uint256 indexed capsuleId,
        address indexed creator,
        uint256 timestamp,
        uint256 nextCheckInDue
    );
    
    event DeadMansSwitchTriggered(
        uint256 indexed capsuleId,
        uint256 timestamp
    );
    
    event GuardianApprovalSubmitted(
        uint256 indexed capsuleId,
        address indexed guardian
    );
    
    event GuardianUnlockTriggered(
        uint256 indexed capsuleId,
        uint256 approvalCount
    );
    
    event RecipientAdded(
        uint256 indexed capsuleId,
        address indexed recipient
    );
    
    event CapsuleCancelled(
        uint256 indexed capsuleId,
        address indexed creator
    );
    
    event SubscriptionPurchased(
        address indexed user,
        string tierName,
        uint256 expiryDate
    );
    
    event PlatformWalletUpdated(
        address indexed oldWallet,
        address indexed newWallet
    );
    
    // ============================================
    // MODIFIERS
    // ============================================
    
    modifier onlyCreator(uint256 _capsuleId) {
        require(capsules[_capsuleId].creator == msg.sender, "Not creator");
        _;
    }
    
    modifier onlyRecipient(uint256 _capsuleId) {
        require(
            capsules[_capsuleId].isRecipient[msg.sender],
            "Not a recipient"
        );
        _;
    }
    
    modifier onlyGuardian(uint256 _capsuleId) {
        require(
            capsules[_capsuleId].isGuardian[msg.sender],
            "Not a guardian"
        );
        _;
    }
    
    modifier capsuleExists(uint256 _capsuleId) {
        require(_capsuleId > 0 && _capsuleId <= capsuleCounter, "Capsule doesn't exist");
        _;
    }
    
    modifier onlyPlatform() {
        require(msg.sender == platformWallet, "Only platform wallet");
        _;
    }
    
    modifier onlyCreatorOrPlatform(uint256 _capsuleId) {
        require(
            capsules[_capsuleId].creator == msg.sender || msg.sender == platformWallet,
            "Not creator or platform"
        );
        _;
    }
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor(address _treasury, address _platformWallet) Ownable(msg.sender) {
        require(_treasury != address(0), "Invalid treasury");
        require(_platformWallet != address(0), "Invalid platform wallet");
        
        treasury = _treasury;
        platformWallet = _platformWallet;
        platformFeePercent = 500; // 5%
        
        // Initialize pricing (in MATIC on Polygon, ~1 MATIC = $1 USD)
        creationFees[CapsuleType.TEXT] = 5 ether;       // $5
        creationFees[CapsuleType.IMAGE] = 10 ether;     // $10
        creationFees[CapsuleType.VIDEO] = 25 ether;     // $25
        creationFees[CapsuleType.DOCUMENT] = 10 ether;  // $10
        creationFees[CapsuleType.MULTI] = 50 ether;     // $50
        
        deadMansSwitchFeePerYear = 20 ether;            // $20/year
        multiRecipientFee = 5 ether;                    // $5
        progressiveUnlockFee = 10 ether;                // $10 per stage
        
        // Initialize subscription tiers
        _initializeTiers();
    }
    
    function _initializeTiers() private {
        // Free tier
        tiers["FREE"] = SubscriptionTier({
            name: "FREE",
            pricePerYear: 0,
            maxCapsules: 1,
            maxStoragePerCapsule: 500 * 1024, // 500 KB
            allowsVideo: false,
            allowsDeadMansSwitch: false,
            allowsMultiRecipient: false,
            allowsProgressiveUnlock: false
        });
        
        // Basic tier
        tiers["BASIC"] = SubscriptionTier({
            name: "BASIC",
            pricePerYear: 29 ether,  // $29/year
            maxCapsules: 5,
            maxStoragePerCapsule: 5 * 1024 * 1024, // 5 MB
            allowsVideo: false,
            allowsDeadMansSwitch: false,
            allowsMultiRecipient: true,
            allowsProgressiveUnlock: false
        });
        
        // Pro tier
        tiers["PRO"] = SubscriptionTier({
            name: "PRO",
            pricePerYear: 99 ether,  // $99/year
            maxCapsules: 999999, // Unlimited
            maxStoragePerCapsule: 100 * 1024 * 1024, // 100 MB
            allowsVideo: true,
            allowsDeadMansSwitch: true,
            allowsMultiRecipient: true,
            allowsProgressiveUnlock: true
        });
        
        // Estate tier
        tiers["ESTATE"] = SubscriptionTier({
            name: "ESTATE",
            pricePerYear: 299 ether,  // $299/year
            maxCapsules: 999999, // Unlimited
            maxStoragePerCapsule: 500 * 1024 * 1024, // 500 MB
            allowsVideo: true,
            allowsDeadMansSwitch: true,
            allowsMultiRecipient: true,
            allowsProgressiveUnlock: true
        });
    }
    
    // ============================================
    // PLATFORM WALLET MANAGEMENT
    // ============================================
    
    function updatePlatformWallet(address _newPlatformWallet) external onlyOwner {
        require(_newPlatformWallet != address(0), "Invalid address");
        address oldWallet = platformWallet;
        platformWallet = _newPlatformWallet;
        emit PlatformWalletUpdated(oldWallet, _newPlatformWallet);
    }
    
    // ============================================
    // SUBSCRIPTION MANAGEMENT
    // ============================================
    
    function purchaseSubscription(string memory _tierName) external payable nonReentrant {
        SubscriptionTier memory tier = tiers[_tierName];
        require(tier.pricePerYear > 0, "Invalid tier");
        require(msg.value >= tier.pricePerYear, "Insufficient payment");
        
        userSubscriptions[msg.sender] = tier;
        subscriptionExpiry[msg.sender] = block.timestamp + 365 days;
        
        // Send payment to treasury
        (bool success, ) = treasury.call{value: msg.value}("");
        require(success, "Payment failed");
        
        emit SubscriptionPurchased(msg.sender, _tierName, subscriptionExpiry[msg.sender]);
    }
    
    function purchaseSubscriptionForUser(
        address _user,
        string memory _tierName
    ) external payable onlyPlatform nonReentrant {
        SubscriptionTier memory tier = tiers[_tierName];
        require(tier.pricePerYear > 0, "Invalid tier");
        require(msg.value >= tier.pricePerYear, "Insufficient payment");
        
        userSubscriptions[_user] = tier;
        subscriptionExpiry[_user] = block.timestamp + 365 days;
        
        // Send payment to treasury
        (bool success, ) = treasury.call{value: msg.value}("");
        require(success, "Payment failed");
        
        emit SubscriptionPurchased(_user, _tierName, subscriptionExpiry[_user]);
    }
    
    function hasActiveSubscription(address _user) public view returns (bool) {
        return subscriptionExpiry[_user] > block.timestamp;
    }
    
    function getUserTier(address _user) public view returns (SubscriptionTier memory) {
        if (hasActiveSubscription(_user)) {
            return userSubscriptions[_user];
        }
        return tiers["FREE"];
    }
    
    // ============================================
    // CAPSULE CREATION (USER PAYS GAS)
    // ============================================
    
    function createCapsule(
        CapsuleType _capsuleType,
        TriggerType _triggerType,
        uint256 _unlockTime,
        string memory _encryptedKeys,
        string memory _ipfsHash,
        address[] memory _recipients,
        string memory _metadata
    ) external payable nonReentrant whenNotPaused returns (uint256) {
        return _createCapsuleInternal(
            msg.sender,
            _capsuleType,
            _triggerType,
            _unlockTime,
            _encryptedKeys,
            _ipfsHash,
            _recipients,
            _metadata,
            false // Not created by platform
        );
    }
    
    // ============================================
    // CAPSULE CREATION (PLATFORM PAYS GAS)
    // ============================================
    
    function createCapsuleForUser(
        address _creator,
        CapsuleType _capsuleType,
        TriggerType _triggerType,
        uint256 _unlockTime,
        string memory _encryptedKeys,
        string memory _ipfsHash,
        address[] memory _recipients,
        string memory _metadata
    ) external payable onlyPlatform nonReentrant whenNotPaused returns (uint256) {
        return _createCapsuleInternal(
            _creator,
            _capsuleType,
            _triggerType,
            _unlockTime,
            _encryptedKeys,
            _ipfsHash,
            _recipients,
            _metadata,
            true // Created by platform
        );
    }
    
    // ============================================
    // INTERNAL CAPSULE CREATION
    // ============================================
    
    function _createCapsuleInternal(
        address _creator,
        CapsuleType _capsuleType,
        TriggerType _triggerType,
        uint256 _unlockTime,
        string memory _encryptedKeys,
        string memory _ipfsHash,
        address[] memory _recipients,
        string memory _metadata,
        bool _createdByPlatform
    ) internal returns (uint256) {
        SubscriptionTier memory tier = getUserTier(_creator);
        
        // Check capsule limit
        require(
            userCapsules[_creator].length < tier.maxCapsules,
            "Capsule limit reached"
        );
        
        // Check video permission
        if (_capsuleType == CapsuleType.VIDEO) {
            require(tier.allowsVideo, "Upgrade to unlock video capsules");
        }
        
        // Check multi-recipient permission
        if (_recipients.length > 1) {
            require(tier.allowsMultiRecipient, "Upgrade for multi-recipient");
        }
        
        // Calculate and check payment
        uint256 totalFee = creationFees[_capsuleType];
        require(msg.value >= totalFee, "Insufficient payment");
        
        // Create capsule
        capsuleCounter++;
        uint256 capsuleId = capsuleCounter;
        
        Capsule storage capsule = capsules[capsuleId];
        capsule.id = capsuleId;
        capsule.creator = _creator;  // Actual owner (not msg.sender if platform)
        capsule.capsuleType = _capsuleType;
        capsule.status = CapsuleStatus.ACTIVE;
        capsule.triggerType = _triggerType;
        capsule.primaryUnlockTime = _unlockTime;
        capsule.createdAt = block.timestamp;
        capsule.maxStorageSize = tier.maxStoragePerCapsule;
        capsule.metadata = _metadata;
        capsule.createdByPlatform = _createdByPlatform;
        
        // Add initial stage
        capsule.stages.push(UnlockStage({
            unlockTime: _unlockTime,
            encryptedKeys: _encryptedKeys,
            ipfsHash: _ipfsHash,
            isUnlocked: false
        }));
        
        // Add recipients
        for (uint256 i = 0; i < _recipients.length; i++) {
            capsule.recipients.push(_recipients[i]);
            capsule.isRecipient[_recipients[i]] = true;
            emit RecipientAdded(capsuleId, _recipients[i]);
        }
        
        // Track user's capsules
        userCapsules[_creator].push(capsuleId);
        
        // Send fee to treasury
        (bool success, ) = treasury.call{value: msg.value}("");
        require(success, "Payment failed");
        
        emit CapsuleCreated(capsuleId, _creator, _capsuleType, _unlockTime, _createdByPlatform);
        
        return capsuleId;
    }
    
    // ============================================
    // PROGRESSIVE UNLOCK (MULTIPLE STAGES)
    // ============================================
    
    function addUnlockStage(
        uint256 _capsuleId,
        uint256 _unlockTime,
        string memory _encryptedKeys,
        string memory _ipfsHash
    ) external payable onlyCreatorOrPlatform(_capsuleId) capsuleExists(_capsuleId) {
        SubscriptionTier memory tier = getUserTier(capsules[_capsuleId].creator);
        require(tier.allowsProgressiveUnlock, "Upgrade for progressive unlock");
        require(msg.value >= progressiveUnlockFee, "Insufficient payment");
        
        Capsule storage capsule = capsules[_capsuleId];
        require(capsule.status == CapsuleStatus.ACTIVE, "Capsule not active");
        
        capsule.stages.push(UnlockStage({
            unlockTime: _unlockTime,
            encryptedKeys: _encryptedKeys,
            ipfsHash: _ipfsHash,
            isUnlocked: false
        }));
        
        capsule.progressiveUnlock = true;
        
        // Send fee to treasury
        (bool success, ) = treasury.call{value: msg.value}("");
        require(success, "Payment failed");
    }
    
    function getUnlockedStages(uint256 _capsuleId) 
        external 
        view 
        capsuleExists(_capsuleId) 
        returns (UnlockStage[] memory) 
    {
        Capsule storage capsule = capsules[_capsuleId];
        
        // Count unlocked stages
        uint256 unlockedCount = 0;
        for (uint256 i = 0; i < capsule.stages.length; i++) {
            if (block.timestamp >= capsule.stages[i].unlockTime) {
                unlockedCount++;
            }
        }
        
        // Create array of unlocked stages
        UnlockStage[] memory unlocked = new UnlockStage[](unlockedCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < capsule.stages.length; i++) {
            if (block.timestamp >= capsule.stages[i].unlockTime) {
                unlocked[index] = capsule.stages[i];
                index++;
            }
        }
        
        return unlocked;
    }
    
    function unlockStage(uint256 _capsuleId, uint256 _stageIndex) 
        external 
        capsuleExists(_capsuleId) 
        onlyRecipient(_capsuleId)
        returns (string memory encryptedKeys, string memory ipfsHash) 
    {
        Capsule storage capsule = capsules[_capsuleId];
        require(_stageIndex < capsule.stages.length, "Invalid stage");
        
        UnlockStage storage stage = capsule.stages[_stageIndex];
        require(block.timestamp >= stage.unlockTime, "Stage still locked");
        require(!stage.isUnlocked, "Stage already unlocked");
        
        stage.isUnlocked = true;
        
        emit CapsuleUnlocked(_capsuleId, msg.sender, _stageIndex);
        
        return (stage.encryptedKeys, stage.ipfsHash);
    }
    
    // ============================================
    // DEAD MAN'S SWITCH
    // ============================================
    
    function enableDeadMansSwitch(
        uint256 _capsuleId,
        uint256 _checkInIntervalDays,
        uint256 _gracePeriodDays
    ) external payable onlyCreatorOrPlatform(_capsuleId) capsuleExists(_capsuleId) {
        SubscriptionTier memory tier = getUserTier(capsules[_capsuleId].creator);
        require(tier.allowsDeadMansSwitch, "Upgrade for dead man's switch");
        require(msg.value >= deadMansSwitchFeePerYear, "Insufficient payment");
        
        Capsule storage capsule = capsules[_capsuleId];
        require(capsule.status == CapsuleStatus.ACTIVE, "Capsule not active");
        
        capsule.hasDeadMansSwitch = true;
        capsule.checkInInterval = _checkInIntervalDays * 1 days;
        capsule.gracePeriod = _gracePeriodDays * 1 days;
        capsule.lastCheckIn = block.timestamp;
        
        // Send fee to treasury
        (bool success, ) = treasury.call{value: msg.value}("");
        require(success, "Payment failed");
    }
    
    function checkIn(uint256 _capsuleId) 
        external 
        onlyCreatorOrPlatform(_capsuleId) 
        capsuleExists(_capsuleId) 
    {
        Capsule storage capsule = capsules[_capsuleId];
        require(capsule.hasDeadMansSwitch, "No dead man's switch enabled");
        require(capsule.status == CapsuleStatus.ACTIVE, "Capsule not active");
        
        capsule.lastCheckIn = block.timestamp;
        
        uint256 nextCheckInDue = block.timestamp + capsule.checkInInterval;
        
        emit CheckInPerformed(_capsuleId, capsule.creator, block.timestamp, nextCheckInDue);
    }
    
    function isDeadMansSwitchTriggered(uint256 _capsuleId) 
        public 
        view 
        capsuleExists(_capsuleId) 
        returns (bool) 
    {
        Capsule storage capsule = capsules[_capsuleId];
        
        if (!capsule.hasDeadMansSwitch) {
            return false;
        }
        
        uint256 deadline = capsule.lastCheckIn + capsule.checkInInterval + capsule.gracePeriod;
        return block.timestamp > deadline;
    }
    
    function triggerDeadMansSwitch(uint256 _capsuleId) 
        external 
        capsuleExists(_capsuleId) 
        onlyRecipient(_capsuleId) 
    {
        require(isDeadMansSwitchTriggered(_capsuleId), "Switch not triggered yet");
        
        Capsule storage capsule = capsules[_capsuleId];
        capsule.status = CapsuleStatus.TRIGGERED;
        
        emit DeadMansSwitchTriggered(_capsuleId, block.timestamp);
    }
    
    function getNextCheckInDeadline(uint256 _capsuleId) 
        external 
        view 
        capsuleExists(_capsuleId) 
        returns (uint256) 
    {
        Capsule storage capsule = capsules[_capsuleId];
        require(capsule.hasDeadMansSwitch, "No dead man's switch");
        
        return capsule.lastCheckIn + capsule.checkInInterval + capsule.gracePeriod;
    }
    
    // ============================================
    // GUARDIAN SYSTEM
    // ============================================
    
    function addGuardians(
        uint256 _capsuleId,
        address[] memory _guardians,
        uint256 _guardiansRequired
    ) external onlyCreatorOrPlatform(_capsuleId) capsuleExists(_capsuleId) {
        Capsule storage capsule = capsules[_capsuleId];
        require(capsule.status == CapsuleStatus.ACTIVE, "Capsule not active");
        require(_guardiansRequired <= _guardians.length, "Invalid threshold");
        
        for (uint256 i = 0; i < _guardians.length; i++) {
            require(_guardians[i] != address(0), "Invalid guardian");
            capsule.guardians.push(_guardians[i]);
            capsule.isGuardian[_guardians[i]] = true;
        }
        
        capsule.guardiansRequired = _guardiansRequired;
    }
    
    function guardianApprove(uint256 _capsuleId) 
        external 
        onlyGuardian(_capsuleId) 
        capsuleExists(_capsuleId) 
    {
        Capsule storage capsule = capsules[_capsuleId];
        require(capsule.status == CapsuleStatus.ACTIVE, "Capsule not active");
        require(!capsule.guardianApproved[msg.sender], "Already approved");
        
        capsule.guardianApproved[msg.sender] = true;
        capsule.guardiansApprovedCount++;
        
        emit GuardianApprovalSubmitted(_capsuleId, msg.sender);
        
        // Check if threshold reached
        if (capsule.guardiansApprovedCount >= capsule.guardiansRequired) {
            capsule.status = CapsuleStatus.UNLOCKED;
            emit GuardianUnlockTriggered(_capsuleId, capsule.guardiansApprovedCount);
        }
    }
    
    // ============================================
    // CAPSULE MANAGEMENT
    // ============================================
    
    function cancelCapsule(uint256 _capsuleId) 
        external 
        onlyCreatorOrPlatform(_capsuleId) 
        capsuleExists(_capsuleId) 
    {
        Capsule storage capsule = capsules[_capsuleId];
        require(capsule.status == CapsuleStatus.ACTIVE, "Capsule not active");
        
        capsule.status = CapsuleStatus.CANCELLED;
        
        emit CapsuleCancelled(_capsuleId, capsule.creator);
    }
    
    function addRecipient(uint256 _capsuleId, address _recipient) 
        external 
        onlyCreatorOrPlatform(_capsuleId) 
        capsuleExists(_capsuleId) 
    {
        Capsule storage capsule = capsules[_capsuleId];
        require(capsule.status == CapsuleStatus.ACTIVE, "Capsule not active");
        require(!capsule.isRecipient[_recipient], "Already a recipient");
        
        capsule.recipients.push(_recipient);
        capsule.isRecipient[_recipient] = true;
        
        emit RecipientAdded(_capsuleId, _recipient);
    }
    
    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    function getCapsule(uint256 _capsuleId) 
        external 
        view 
        capsuleExists(_capsuleId) 
        returns (
            uint256 id,
            address creator,
            CapsuleType capsuleType,
            CapsuleStatus status,
            uint256 unlockTime,
            uint256 createdAt,
            address[] memory recipients,
            bool hasDeadMansSwitch,
            bool progressiveUnlock,
            bool createdByPlatform
        ) 
    {
        Capsule storage capsule = capsules[_capsuleId];
        
        return (
            capsule.id,
            capsule.creator,
            capsule.capsuleType,
            capsule.status,
            capsule.primaryUnlockTime,
            capsule.createdAt,
            capsule.recipients,
            capsule.hasDeadMansSwitch,
            capsule.progressiveUnlock,
            capsule.createdByPlatform
        );
    }
    
    function getUserCapsules(address _user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userCapsules[_user];
    }
    
    function getCapsuleStageCount(uint256 _capsuleId) 
        external 
        view 
        capsuleExists(_capsuleId) 
        returns (uint256) 
    {
        return capsules[_capsuleId].stages.length;
    }
    
    function isUnlocked(uint256 _capsuleId) 
        public 
        view 
        capsuleExists(_capsuleId) 
        returns (bool) 
    {
        Capsule storage capsule = capsules[_capsuleId];
        
        // Check if manually unlocked by guardians
        if (capsule.status == CapsuleStatus.UNLOCKED) {
            return true;
        }
        
        // Check if dead man's switch triggered
        if (capsule.status == CapsuleStatus.TRIGGERED) {
            return true;
        }
        
        // Check if time-based unlock reached
        if (block.timestamp >= capsule.primaryUnlockTime) {
            return true;
        }
        
        return false;
    }
    
    // ============================================
    // ADMIN FUNCTIONS
    // ============================================
    
    function updatePricing(
        CapsuleType _type,
        uint256 _newFee
    ) external onlyOwner {
        creationFees[_type] = _newFee;
    }
    
    function updateTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Invalid address");
        treasury = _newTreasury;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function emergencyWithdraw() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }
}
