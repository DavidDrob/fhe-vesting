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
        staking = new StakingReference(address(stakingToken), address(rewardToken), vestingStart, 7 days, 7 days);

        stakingToken.mint(alice, 100 ether);
        stakingToken.mint(bob, 200 ether);

        rewardToken.mint(rewarder, 1_000 ether);

        vm.startPrank(rewarder);
        rewardToken.approve(address(staking), 1_000 ether);
        staking.addRewards(1_000 ether);
        vm.stopPrank();

        vm.prank(alice);
        stakingToken.approve(address(staking), type(uint256).max);

        vm.prank(bob);
        stakingToken.approve(address(staking), type(uint256).max);
    }

    function testStake() public {
        vm.prank(alice);
        staking.stake(50 ether);

        assertEq(staking.userShares(alice), 50 ether);
    }

    function testUnstake() public {
        vm.prank(alice);
        staking.stake(50 ether);

        assertEq(staking.userShares(alice), 50 ether);

        skip(14 days + 3 days); // vesting start + 3 days

        uint256 aliceRewardBefore = rewardToken.balanceOf(alice);

        vm.startPrank(alice);
        staking.claim(alice);
        staking.unstake(50 ether);
        vm.stopPrank();

        assertGt(rewardToken.balanceOf(alice), aliceRewardBefore);

        assertEq(staking.userShares(alice), 0);

        skip(4 days);

        vm.prank(alice);
        vm.expectRevert();
        staking.claim(alice);
    }

    function testCantStakeAfterStakingPeriod() public {
        skip(8 days);

        vm.prank(alice);
        vm.expectRevert();
        staking.stake(50 ether);
    }

    function testClaimRewardsBeforeEnd() public {
        vm.prank(alice);
        staking.stake(50 ether);

        vm.prank(bob);
        staking.stake(77 ether);

        skip(14 days + 3 days); // vesting start + 3 days

        uint256 aliceRewardBefore = rewardToken.balanceOf(alice);
        uint256 bobRewardBefore = rewardToken.balanceOf(bob);

        vm.prank(alice);
        staking.claim(alice);

        vm.prank(bob);
        staking.claim(bob);

        uint256 aliceRewardAfter = rewardToken.balanceOf(alice);
        uint256 bobRewardAfter = rewardToken.balanceOf(bob);

        assertGt(aliceRewardAfter, aliceRewardBefore);
        assertGt(bobRewardAfter, aliceRewardAfter);

        vm.prank(bob);
        vm.expectRevert();
        staking.claim(bob);
    }

    function testClaimRewardsFully() public {
        uint256 aliceStakeBefore = stakingToken.balanceOf(alice);

        vm.prank(alice);
        staking.stake(50e18);

        vm.prank(bob);
        staking.stake(77e18);

        // end of vesting
        skip(22 days);

        assertEq(staking.vestingSchedule(uint64(block.timestamp)), 1_000e18);

        uint256 aliceRewardBefore = rewardToken.balanceOf(alice);
        uint256 bobRewardBefore = rewardToken.balanceOf(bob);

        vm.prank(alice);
        staking.claim(alice);

        vm.prank(bob);
        staking.claim(bob);

        uint256 aliceRewardAfter = rewardToken.balanceOf(alice);
        uint256 bobRewardAfter = rewardToken.balanceOf(bob);

        // some dust will remain in the contract
        assertApproxEqRel(aliceRewardAfter + bobRewardAfter, 1_000e18, 0.1e18);
        assertLt(rewardToken.balanceOf(address(staking)), 10);
        assertGt(bobRewardAfter, aliceRewardAfter);

        vm.prank(bob);
        vm.expectRevert();
        staking.claim(bob);

        vm.prank(alice);
        staking.unstake(50e18);

        assertEq(aliceStakeBefore, stakingToken.balanceOf(alice));
    }

    function testClaimReceiver() public {
        vm.prank(alice);
        staking.stake(50e18);

        // end of vesting
        skip(22 days);

        uint256 aliceRewardBefore = rewardToken.balanceOf(alice);
        uint256 bobRewardBefore = rewardToken.balanceOf(bob);

        vm.prank(alice);
        staking.claim(bob);

        uint256 aliceRewardAfter = rewardToken.balanceOf(alice);
        uint256 bobRewardAfter = rewardToken.balanceOf(bob);

        assertEq(aliceRewardAfter, 0);
        assertEq(bobRewardAfter, 1_000e18);
    }
}
