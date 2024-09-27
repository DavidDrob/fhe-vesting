// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/*
    TODO: allow adding multiple rewards
*/

import "@openzeppelin/token/ERC20/IERC20.sol";

// Errors
error StakingReference_StakingStartMustBeInTheFuture();
error StakingReference_StakingEnded();
error StakingReference_VestingStarted();
error StakingReference_AmountZero();
error StakingReference_AddressZero();
error StakingReference_AmountGreaterThanAvailable();
error StakingReference_NoTokensClaimable();

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
        if (startTimestamp <= block.timestamp) revert StakingReference_StakingStartMustBeInTheFuture();

        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);

        start = startTimestamp;
        duration = durationSeconds;
    }

    function stake(uint256 _amount) external {
        if (block.timestamp > start - stakingPeriod) revert StakingReference_StakingEnded();
        if (_amount == 0) revert StakingReference_AmountZero();

        stakingToken.transferFrom(msg.sender, address(this), _amount);

        _addShares(msg.sender, _amount);
    }

    function unstake(uint256 _amount) external {
        if (_amount == 0) revert StakingReference_AmountZero();
        if (userShares[msg.sender] > _amount) revert StakingReference_AmountGreaterThanAvailable();

        _removeShares(msg.sender, _amount);

        stakingToken.transfer(msg.sender, _amount);
    }

    function addRewards(uint256 _amount) external {
        if (block.timestamp >= start) revert StakingReference_VestingStarted();
        if (_amount == 0) revert StakingReference_AmountZero();

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

    function claim(address receiver) public {
        if (receiver == address(0)) revert StakingReference_AddressZero();

        uint256 amount = claimable(msg.sender);
        if (amount == 0) revert StakingReference_NoTokensClaimable();

        rewardsReceived[msg.sender] += amount;

        rewardToken.transfer(receiver, amount);
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
