// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/StakingReference.sol";
import "../src/MockERC20.sol";

contract StakingReferenceTest is Test {
    StakingReference staking;
    MockERC20 stakingToken;
    MockERC20 rewardToken;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    address rewarder = makeAddr("rewarder");

    function setUp() public {
        stakingToken = new MockERC20("StakingToken", "STK");
        rewardToken = new MockERC20("RewardToken", "RTK");

        uint64 vestingStart = uint64(block.timestamp + 14 days);
        staking = new StakingReference(address(stakingToken), address(rewardToken), vestingStart, 7 days);

        stakingToken.mint(alice, 100 ether);
        stakingToken.mint(bob, 200 ether);

        rewardToken.mint(rewarder, 1_000 ether);

        vm.startPrank(rewarder);
        rewardToken.approve(address(staking), 1_000 ether);
        staking.addRewards(1_000 ether);
        vm.stopPrank();
    }

    function testStake() public {
        vm.startPrank(alice);
        stakingToken.approve(address(staking), 50 ether);
        staking.stake(50 ether);
        vm.stopPrank();

        assertEq(staking.userShares(alice), 50 ether);
    }
}
