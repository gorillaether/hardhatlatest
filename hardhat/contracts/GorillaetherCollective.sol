// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GorillaetherCollective
 * @dev A collective for DApp builders, managing memberships, project tipping, and a treasury.
 * Membership fee is initially set at 10 MATIC.
 */
contract GorillaetherCollective is Ownable {
    // ==============
    // State Variables
    // ==============

    uint256 public membershipFee;
    mapping(address => bool) public members; // Tracks if an address is a member
    uint256 public totalMembers;

    // Tracks funds raised per project (identified by project beneficiary address)
    mapping(address => uint256) public projectFundsRaised;

    // ==============
    // Events
    // ==============

    event MemberJoined(address indexed member, uint256 amountPaid);
    event ProjectTipped(address indexed from, address indexed toProjectBeneficiary, uint256 amount);
    event FundsDistributed(address indexed recipient, uint256 amount); // In ABI, 'creator' was used for recipient

    // ==============
    // Constructor
    // ==============

    /**
     * @dev Sets the initial membership fee and transfers ownership to the deployer.
     * @param _initialMembershipFee The initial fee to join the collective (e.g., 10 * 10**18 for 10 MATIC).
     */
    constructor(uint256 _initialMembershipFee) Ownable(msg.sender) {
        membershipFee = _initialMembershipFee;
    }

    // ==============
    // Member Functions
    // ==============

    /**
     * @dev Allows a user to join the collective by paying the membership fee.
     */
    function joinCollective() external payable {
        require(msg.value == membershipFee, "GorillaetherCollective: Incorrect membership fee paid");
        require(!members[msg.sender], "GorillaetherCollective: Already a member");

        members[msg.sender] = true;
        totalMembers++;
        emit MemberJoined(msg.sender, msg.value);
    }

    /**
     * @dev Allows anyone to tip a project.
     * @param _projectBeneficiary The address that will receive the tipped funds for the project.
     */
    function tipProject(address _projectBeneficiary) external payable {
        require(_projectBeneficiary != address(0), "GorillaetherCollective: Project beneficiary cannot be zero address");
        require(msg.value > 0, "GorillaetherCollective: Tip amount must be greater than zero");

        projectFundsRaised[_projectBeneficiary] += msg.value;
        // Note: The funds msg.value are added to the contract's balance here.
        // If tips should go directly to _projectBeneficiary, this function needs modification
        // or a separate withdrawal mechanism for project beneficiaries.
        // For now, this function behaves as if tips contribute to a project's "account" within the collective's treasury,
        // which can then be distributed via other means if necessary.
        // However, a common pattern for tipping is direct transfer:
        // (bool success, ) = _projectBeneficiary.call{value: msg.value}("");
        // require(success, "GorillaetherCollective: Tip transfer failed");
        // If using direct transfer, the projectFundsRaised mapping might still be useful for tracking.

        emit ProjectTipped(msg.sender, _projectBeneficiary, msg.value);
    }

    // ==============
    // Owner Functions
    // ==============

    /**
     * @dev Allows the owner to set a new membership fee.
     * @param _newFee The new membership fee.
     */
    function setMembershipFee(uint256 _newFee) external onlyOwner {
        membershipFee = _newFee;
    }

    /**
     * @dev Allows the owner to distribute funds from the collective's treasury.
     * The ABI parameter name for the recipient was 'creator'. Here, '_to' is used for clarity.
     * @param _to The address to receive the funds.
     * @param _amount The amount of funds to distribute.
     */
    function distributeTreasuryFunds(address payable _to, uint256 _amount) external onlyOwner {
        require(_to != address(0), "GorillaetherCollective: Cannot distribute to zero address");
        require(_amount > 0, "GorillaetherCollective: Distribution amount must be greater than zero");
        require(address(this).balance >= _amount, "GorillaetherCollective: Insufficient treasury balance");

        (bool success, ) = _to.call{value: _amount}("");
        require(success, "GorillaetherCollective: Treasury fund distribution failed");

        emit FundsDistributed(_to, _amount);
    }

    // ==============
    // View Functions
    // ==============

    /**
     * @dev Checks if an address is a member.
     * This is implicitly available via the public `members` mapping,
     * but an explicit getter can be convenient for some interfaces.
     * The ABI implies `members(address)` directly.
     */
    function isMember(address _user) external view returns (bool) {
        return members[_user];
    }
    
    /**
     * @dev Returns the current membership fee.
     * This is implicitly available via the public `membershipFee` variable.
     * The ABI implies `membershipFee()` directly.
     */
    function getMembershipFee() external view returns (uint256) {
        return membershipFee;
    }

    /**
     * @dev Returns the total balance of the contract's treasury.
     * The ABI implies `treasuryBalance()` directly.
     */
    function getTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Returns the funds raised for a specific project beneficiary.
     * This is implicitly available via the public `projectFundsRaised` mapping.
     */
    function getProjectFundsRaised(address _projectBeneficiary) external view returns (uint256) {
        return projectFundsRaised[_projectBeneficiary];
    }

    // Note on Project Management:
    // The frontend files (ProjectCard.jsx, dashboard.js) suggest more detailed project information
    // (title, description, funding goals, voting, status).
    // To manage these on-chain, you would typically add:
    // - A struct `Project { string title; address creator; uint256 fundingGoal; uint256 currentRaised; ... }`
    // - A mapping `mapping(uint256 => Project) public projects;` (or address => Project if project ID is an address)
    // - Functions to create projects/proposals, vote on them, update their status, etc.
    // - The `tipProject` function might then take a project ID instead of a beneficiary address.
    // This skeleton focuses on the direct ABI provided and basic functionality.

    // Note on Fee Splitting:
    // The UI mentioned a split of the membership fee (e.g., 0.007 for platform, 0.003 for treasury).
    // The current `joinCollective` function sends the entire fee to this contract's treasury.
    // To implement a split, `joinCollective` would need modification:
    // 1. A state variable for the platform operations address: `address public platformWallet;`
    // 2. In the constructor, set this address: `platformWallet = _platformAddress;` (requires adding a constructor param)
    // 3. In `joinCollective`, after fee checks:
    //    `uint256 platformShare = (membershipFee * 70) / 100; // if membershipFee is 10 MATIC, platformShare is 7 MATIC`
    //    `uint256 treasuryShare = membershipFee - platformShare; // treasuryShare is 3 MATIC`
    //    `(bool success, ) = platformWallet.call{value: platformShare}("");`
    //    `require(success, "Fee split transfer failed");`
    //    The remaining `msg.value` (which would be `treasuryShare` if msg.value was exactly membershipFee)
    //    naturally stays with the contract. Ensure `msg.value` handling is correct if it can exceed `membershipFee`.
}
