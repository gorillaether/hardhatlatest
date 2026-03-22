// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IPriceFeed {
    function latestAnswer() external view returns (int256);
}

contract PCEIndexedLease {
    address public landlord;
    address public tenant;
    IERC20 public payToken;
    IPriceFeed public pceFeed;

    uint256 public baseRent;
    uint256 public periodSeconds;
    uint256 public startTime;
    uint256 public endTime;
    bool public upOnly;
    uint256 public capUpPerPeriod1e18;
    uint256 public capDownPerPeriod1e18;
    uint256 public minRentFloor;
    uint256 public lateFeeFixed;

    constructor(
        address _landlord,
        address _tenant,
        address _payToken,
        address _pceFeed,
        uint256 _baseRent,
        uint256 _periodSeconds,
        uint256 _startTime,
        uint256 _endTime,
        bool _upOnly,
        uint256 _capUpPerPeriod1e18,
        uint256 _capDownPerPeriod1e18,
        uint256 _minRentFloor,
        uint256 _lateFeeFixed
    ) {
        landlord = _landlord;
        tenant = _tenant;
        payToken = IERC20(_payToken);
        pceFeed = IPriceFeed(_pceFeed);
        baseRent = _baseRent;
        periodSeconds = _periodSeconds;
        startTime = _startTime;
        endTime = _endTime;
        upOnly = _upOnly;
        capUpPerPeriod1e18 = _capUpPerPeriod1e18;
        capDownPerPeriod1e18 = _capDownPerPeriod1e18;
        minRentFloor = _minRentFloor;
        lateFeeFixed = _lateFeeFixed;
    }

    // Placeholder function: you can expand payment logic
    function payRent() external {
        require(msg.sender == tenant, "Only tenant can pay");
        uint256 amount = baseRent;
        payToken.transferFrom(tenant, landlord, amount);
    }

    function getCurrentPCE() public view returns (int256) {
        return pceFeed.latestAnswer();
    }
}