// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
    TODO: allow adding multiple reward tokens
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    uint64 public immutable stakingPeriod;

    uint256 public totalShares;
    mapping(address user => uint256 shares) public userShares;
    
    /// @notice Initialize the staking contract
    /// @param _stakingToken token a user can deposit to be eligible for rewards
    /// @param _rewardToken reward token
    /// @param _startTimestamp vesting start
    /// @param _duration vesting duration
    /// @param _stakingPeriod time before vesting starts. The user will not be able to stake after this period
    constructor(address _stakingToken, address _rewardToken, uint64 _startTimestamp, uint64 _duration, uint64 _stakingPeriod) {
        if (_startTimestamp <= block.timestamp) revert StakingReference_StakingStartMustBeInTheFuture();
        if (_duration == 0 || _stakingPeriod == 0) revert StakingReference_AmountZero();

        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);

        start = _startTimestamp;
        duration = _duration;
        stakingPeriod = _stakingPeriod;
    }

    /// @notice Staking `stakingToken` and receive shares
    /// @param _amount amount of `stakingToken`
    function stake(uint256 _amount) external {
        if (block.timestamp > start - stakingPeriod) revert StakingReference_StakingEnded();
        if (_amount == 0) revert StakingReference_AmountZero();

        stakingToken.transferFrom(msg.sender, address(this), _amount);

        _addShares(msg.sender, _amount);
    }

    /// @notice Unstake `_stakingToken` and burn shares
    /// @param _amount amount of `_stakingToken`
    function unstake(uint256 _amount) external {
        if (_amount == 0) revert StakingReference_AmountZero();
        if (userShares[msg.sender] > _amount) revert StakingReference_AmountGreaterThanAvailable();

        _removeShares(msg.sender, _amount);

        stakingToken.transfer(msg.sender, _amount);
    }

    /// @notice Anyone can add any amount of `rewardToken` prior to the vesting start
    /// @param _amount amount of `rewardToken`
    function addRewards(uint256 _amount) external {
        if (block.timestamp >= start) revert StakingReference_VestingStarted();
        if (_amount == 0) revert StakingReference_AmountZero();

        rewardToken.transferFrom(msg.sender, address(this), _amount);

        totalRewards += _amount;
    }

    /// @notice Internal function to account for shares
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

    /// @notice Returns amount of `rewardToken` a user can claim at current block.timestamp
    function claimable(address user) public view returns (uint256) {
        uint256 rewardsAvailable = vestingSchedule(uint64(block.timestamp));
        uint256 userTotalAllocation = (userShares[user] * rewardsAvailable) / totalShares;
        return userTotalAllocation - rewardsReceived[user];
    }

    /// @notice Claim pending rewards for a user
    /// @param receiver Arbitrary receiver of the rewards
    function claim(address receiver) public {
        if (receiver == address(0)) revert StakingReference_AddressZero();

        uint256 amount = claimable(msg.sender);
        if (amount == 0) revert StakingReference_NoTokensClaimable();

        rewardsReceived[msg.sender] += amount;

        rewardToken.transfer(receiver, amount);
    }

    /// @notice Returns vested reward tokens at a specific timestamp
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

