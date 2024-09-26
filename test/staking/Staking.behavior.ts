import { expect, assert } from "chai";
import hre from "hardhat";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const ONE_WEEK = 7 * 24 * 60 * 60;

export function shouldBehaveLikeStaking(): void {
  it("should setup correctly", async function () {
    const delay = await this.staking.delay();
    const stakingToken = await this.staking.stakingToken();

    expect(Number(delay)).to.be.equal(ONE_WEEK);
    expect(stakingToken).to.not.be.equal(ZERO_ADDRESS);
  });
}
