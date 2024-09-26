import { createPermitForContract } from "../../utils/instance";
import type { Signers } from "../types";
import { shouldBehaveLikeStaking } from "./Staking.behavior";
import { deployStakingFixture, getTokensFromFaucet } from "./Staking.fixture";
import hre from "hardhat";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    // get tokens from faucet if we're on localfhenix and don't have a balance
    await getTokensFromFaucet();

    const { staking, address } = await deployStakingFixture();
    this.staking = staking;

    // initiate fhenixjs
    this.permission = await createPermitForContract(hre, address);
    this.fhenixjs = hre.fhenixjs;

    // set admin account/signer
    const signers = await hre.ethers.getSigners();
    this.signers.admin = signers[0];
  });

  describe("Staking", function () {
    shouldBehaveLikeStaking();
  });
});
