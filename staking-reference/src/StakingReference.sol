// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/*
    TODO: allow adding multiple rewards
    TODO: add receiver address to claimRewards
*/

import "@openzeppelin/token/ERC20/IERC20.sol";

contract StakingReference {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    mapping(address user => uint256 amount) public rewardsReceived;
    uint256 public totalRewards;

    uint64 public immutable start;
    uint64 public immutable duration;
    uint256 public totalShares;
    mapping(address user => uint256 shares) public userShares;

    uint64 public constant stakingPeriod = 7 days;
    
    constructor(address _stakingToken, address _rewardToken, uint64 startTimestamp, uint64 durationSeconds) {
        require(startTimestamp > block.timestamp, "Start time must be in the future");

        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);

        start = startTimestamp;
        duration = durationSeconds;
    }

    function stake(uint256 _amount) external {
        require(block.timestamp <= start - stakingPeriod, "Staking period has ended");
        require(_amount > 0, "No tokens sent");

        stakingToken.transferFrom(msg.sender, address(this), _amount);

        _addShares(msg.sender, _amount);
    }

    function unstake(uint256 _amount) external {
        require(_amount > 0, "No tokens staked");
        require(userShares[msg.sender] <= _amount, "Amount larger than staked tokens");

        _removeShares(msg.sender, _amount);

        stakingToken.transfer(msg.sender, _amount);
    }

    function addRewards(uint256 _amount) external {
        require(block.timestamp < start, "Vesting started");
        require(_amount > 0, "No tokens sent");

        rewardToken.transferFrom(msg.sender, address(this), _amount);

        totalRewards += _amount;
    }

    function _addShares(address _user, uint256 _amount) internal {
        userShares[_user] += _amount;
        totalShares += _amount;
    }

    function _removeShares(address _user, uint256 _amount) internal {
        userShares[_user] -= _amount;
        totalShares -= _amount;
    }

    function end() public view returns (uint256) {
        return start + duration;
    }

    function claimable(address user) public view returns (uint256) {
        uint256 rewardsAvailable = vestingSchedule(uint64(block.timestamp));
        uint256 userTotalAllocation = (userShares[user] * rewardsAvailable) / totalShares;
        return userTotalAllocation - rewardsReceived[user];
    }

    function claim() public {
        uint256 amount = claimable(msg.sender);
        require(amount > 0, "No tokens claimable");

        rewardsReceived[msg.sender] += amount;

        rewardToken.transfer(msg.sender, amount);
    }

    function vestingSchedule(uint64 timestamp) public view returns (uint256) {
        if (timestamp < start) {
            return 0;
        } else if (timestamp >= end()) {
            return totalRewards;
        } else {
            return (totalRewards * (timestamp - start)) / duration;
        }
    }
}
