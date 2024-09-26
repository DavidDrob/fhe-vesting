// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
    TODO: Users should be
        eligible for rewards only when they
        stake `delay` before `vestingStart`
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingLinearVesting {
    // tokens
    IERC20 public stakingToken;
    IERC20 public rewardToken;

    // accounting
    mapping(address user => uint256 amount) public stakedAmount;
    uint256 public totalStaked;

    mapping(address user => uint256 amount) public rewardsReceived;
    uint256 public totalRewards;

    // vesting
    uint256 public vestingStart;
    uint256 public vestingDuration;
    uint256 public delay;

    constructor(address _stakingToken, address _rewardToken, uint256 _vestingStart, uint256 _vestingDuration, uint256 _delay) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);

        vestingStart = _vestingStart;
        vestingDuration = _vestingDuration;
        delay = _delay;
    }

    function pendingRewards(address _user) public view returns (uint256) {
        uint256 stakedAmount = stakedAmount[_user];
        uint256 rewardsReceived = rewardsReceived[_user];
        uint256 rewardPerToken = (totalRewards * (block.timestamp - vestingStart) / vestingDuration) / totalStaked;

        return (stakedAmount * rewardPerToken) - rewardsReceived;
    }

    function stake(uint256 _amount) external {
        require(_amount > 0);
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        stakedAmount[msg.sender] += _amount;
        totalStaked += _amount;
    }

    // TODO: add receiver argument
    function claimRewards() external {
        require(block.timestamp >= vestingStart);

        uint256 rewards = pendingRewards(msg.sender);

        rewardsReceived[msg.sender] += rewards;

        rewardToken.transferFrom(address(this), msg.sender, rewards);
    }

    function addRewards(uint256 _amount) external {
        require(_amount > 0);
        rewardToken.transferFrom(msg.sender, address(this), _amount);

        totalRewards += _amount;
    }
}
