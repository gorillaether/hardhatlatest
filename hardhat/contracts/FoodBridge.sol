// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FoodBridge is Ownable {
    uint256 public nextListingId;
    mapping(uint256 => DonationListing) public donationListings;
    mapping(address => bool) public isRestaurant;
    mapping(address => bool) public isAidOrganization;
    mapping(address => bool) public isVolunteer;

    enum DonationStatus { Active, Claimed, PickedUp, Delivered, Expired, Cancelled }

    struct DonationListing {
        uint256 listingId;
        address restaurantAddress;
        string foodDetails;
        string quantity;
        string pickupLocationRef;
        uint256 availableStartTime;
        uint256 availableEndTime;
        DonationStatus currentStatus;
        address claimedBy;
        uint256 claimTime;
        uint256 pickupConfirmTime;
        address receivedBy;
        uint256 receiptConfirmTime;
    }

    event ListingCreated(uint256 listingId, address indexed restaurant, string foodDetails, uint256 startTime, uint256 endTime);
    event ListingClaimed(uint256 indexed listingId, address indexed claimedBy, uint256 claimTime);
    event PickupConfirmed(uint256 indexed listingId, address indexed confirmedBy, uint256 confirmTime); // Note: Fixed uint255 typo to uint256 if it existed
    event ReceiptConfirmed(uint256 indexed listingId, address indexed confirmedBy, uint256 confirmTime);
    event ListingExpired(uint256 indexed listingId);
    event ListingCancelled(uint256 indexed listingId, address indexed cancelledBy);

    constructor() Ownable(msg.sender) {
        nextListingId = 1;
    }

    function registerRestaurant(address restaurantAddress, bytes32 offchainProfileHash) public onlyOwner {
        require(!isRestaurant[restaurantAddress], "Address is already registered as a restaurant");
        isRestaurant[restaurantAddress] = true;
    }

    function registerAidOrganization(address orgAddress, bytes32 offchainProfileHash) public onlyOwner {
        require(!isAidOrganization[orgAddress], "Address is already registered as an aid organization");
        isAidOrganization[orgAddress] = true;
    }

    function registerVolunteer(address volunteerAddress, bytes32 offchainProfileHash) public onlyOwner {
         require(!isVolunteer[volunteerAddress], "Address is already registered as a volunteer");
        isVolunteer[volunteerAddress] = true;
    }

    function createListing(
        string memory _foodDetails,
        string memory _quantity,
        string memory _pickupLocationRef,
        uint256 _availableStartTime,
        uint256 _availableEndTime
    ) public {
        require(isRestaurant[msg.sender], "Only registered restaurants can create listings");
        require(_availableStartTime < _availableEndTime, "End time must be after start time");
        require(_availableStartTime >= block.timestamp, "Start time cannot be in the past");

        uint256 currentListingId = nextListingId;

        donationListings[currentListingId] = DonationListing({
            listingId: currentListingId,
            restaurantAddress: msg.sender,
            foodDetails: _foodDetails,
            quantity: _quantity,
            pickupLocationRef: _pickupLocationRef,
            availableStartTime: _availableStartTime,
            availableEndTime: _availableEndTime,
            currentStatus: DonationStatus.Active,
            claimedBy: address(0),
            claimTime: 0,
            pickupConfirmTime: 0,
            receivedBy: address(0),
            receiptConfirmTime: 0
        });

        nextListingId++;

        emit ListingCreated(currentListingId, msg.sender, _foodDetails, _availableStartTime, _availableEndTime);
    }

    function claimListing(uint256 _listingId) public {
        require(isVolunteer[msg.sender] || isAidOrganization[msg.sender], "Only registered volunteers or aid organizations can claim listings");
        require(donationListings[_listingId].restaurantAddress != address(0), "Listing does not exist");
        require(donationListings[_listingId].currentStatus == DonationStatus.Active, "Listing is not active");
        require(block.timestamp >= donationListings[_listingId].availableStartTime && block.timestamp <= donationListings[_listingId].availableEndTime, "Listing is outside the available pickup window");

        donationListings[_listingId].currentStatus = DonationStatus.Claimed;
        donationListings[_listingId].claimedBy = msg.sender;
        donationListings[_listingId].claimTime = block.timestamp;

        emit ListingClaimed(_listingId, msg.sender, block.timestamp);
    }

    function confirmPickup(uint256 _listingId) public {
        require(donationListings[_listingId].restaurantAddress != address(0), "Listing does not exist");
        require(donationListings[_listingId].currentStatus == DonationStatus.Claimed, "Listing is not claimed");
        require(donationListings[_listingId].claimedBy == msg.sender, "Only the claimant can confirm pickup");

        donationListings[_listingId].currentStatus = DonationStatus.PickedUp;
        donationListings[_listingId].pickupConfirmTime = block.timestamp;

        emit PickupConfirmed(_listingId, msg.sender, block.timestamp);
    }

    function confirmReceipt(uint256 _listingId) public {
         require(isAidOrganization[msg.sender], "Only registered aid organizations can confirm receipt");
        require(donationListings[_listingId].restaurantAddress != address(0), "Listing does not exist");
        require(donationListings[_listingId].currentStatus == DonationStatus.PickedUp, "Listing has not been picked up");

        donationListings[_listingId].currentStatus = DonationStatus.Delivered;
        donationListings[_listingId].receivedBy = msg.sender;
        donationListings[_listingId].receiptConfirmTime = block.timestamp;

        emit ReceiptConfirmed(_listingId, msg.sender, block.timestamp);
    }

    function cancelListing(uint256 _listingId) public {
        require(donationListings[_listingId].restaurantAddress != address(0), "Listing does not exist");
        require(donationListings[_listingId].restaurantAddress == msg.sender, "Only the restaurant can cancel their listing");
        require(donationListings[_listingId].currentStatus != DonationStatus.Delivered && donationListings[_listingId].currentStatus != DonationStatus.Expired, "Listing cannot be cancelled in its current state");

        donationListings[_listingId].currentStatus = DonationStatus.Cancelled;

        emit ListingCancelled(_listingId, msg.sender);
    }

    function markExpired(uint256 _listingId) public {
        require(donationListings[_listingId].restaurantAddress != address(0), "Listing does not exist");
        require(donationListings[_listingId].currentStatus == DonationStatus.Active || donationListings[_listingId].currentStatus == DonationStatus.Claimed, "Listing is not in a state to be expired");
        require(block.timestamp > donationListings[_listingId].availableEndTime, "Listing has not expired yet");

        donationListings[_listingId].currentStatus = DonationStatus.Expired;
        emit ListingExpired(_listingId);
    }

    function getListingStatus(uint256 _listingId) public view returns (DonationStatus) {
        require(donationListings[_listingId].restaurantAddress != address(0), "Listing does not exist");
        return donationListings[_listingId].currentStatus;
    }
}