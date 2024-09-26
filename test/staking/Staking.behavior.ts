import { expect, assert } from "chai";
import hre from "hardhat";
import { ethers } from "hardhat";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const ONE_WEEK = 7 * 24 * 60 * 60;
const ONE_MILLION = ethers.toBigInt("1000000000000000000000000")
const ONE_HUNDRED = ethers.toBigInt("100000000000000000000")

export function shouldBehaveLikeStaking(): void {
  it("should setup correctly", async function () {
    const delay = await this.staking.delay();
    const stakingToken = await this.staking.stakingToken();

    expect(Number(delay)).to.be.equal(ONE_WEEK);
    expect(stakingToken).to.not.be.equal(ZERO_ADDRESS);
  });
  it("should be able to stake", async function () {
    const [alice] = await ethers.getSigners();
    
    const aliceBalance = await this.mockStaking.balanceOf(alice.address);
    expect(aliceBalance).to.equal(ONE_MILLION);

    await this.mockStaking.connect(alice).approve(this.staking, ONE_HUNDRED);

    await this.staking.connect(alice).stake(ONE_HUNDRED);

    const aliceStaked = await this.staking.stakedAmount(alice.address);

    expect(aliceStaked).to.equal(ONE_HUNDRED);
  });
  it("should not be able to claim when there are no rewards", async function () {
    const [alice] = await ethers.getSigners();

    await this.mockStaking.connect(alice).approve(this.staking, ONE_HUNDRED);
    await this.staking.connect(alice).stake(ONE_HUNDRED);

    const nineDays = 9 * 24 * 60 * 60;
    await ethers.provider.send("evm_increaseTime", [nineDays]);
    await ethers.provider.send("evm_mine", []);

    const rewards = await this.staking.pendingRewards(alice);
    expect(Number(rewards)).to.be.equal(0);
  });
  it("should be able to claim rewards", async function () {
    const [alice, bob] = await ethers.getSigners();

    await this.mockReward.connect(bob).mint(ONE_MILLION);
    await this.mockReward.connect(bob).approve(this.staking, ONE_MILLION);
    await this.staking.connect(bob).addRewards(ONE_MILLION);

    await this.mockStaking.connect(alice).approve(this.staking, ONE_HUNDRED);
    await this.staking.connect(alice).stake(ONE_HUNDRED);

    const nineDays = 9 * 24 * 60 * 60;
    await ethers.provider.send("evm_increaseTime", [nineDays]);
    await ethers.provider.send("evm_mine", []);

    const rewards = await this.staking.pendingRewards(alice);
    expect(Number(rewards)).to.not.be.equal(0);
  });
}
