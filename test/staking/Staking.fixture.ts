import type { StakingLinearVesting, MockERC20 } from "../../types";
import axios from "axios";
import hre from "hardhat";
import { ethers  } from "hardhat";

const ONE_MILLION = ethers.toBigInt("1000000000000000000000000");
 
export async function deployStakingFixture(): Promise<{
  mockStakingToken: MockERC20;
  mockRewardToken: MockERC20;
  staking: StakingLinearVesting;
  address: string;
}> {
  const accounts = await hre.ethers.getSigners();
  const contractOwner = accounts[0];

  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const mockStakingToken = await MockERC20.deploy(ONE_MILLION);
  await mockStakingToken.waitForDeployment();
  const mockStakingTokenAddress = await mockStakingToken.getAddress();

  const mockRewardToken = await MockERC20.deploy(ONE_MILLION);
  await mockRewardToken.waitForDeployment();
  const mockRewardTokenAddress = await mockRewardToken.getAddress();

  const blockNumber = await ethers.provider.getBlockNumber();
  const block = await ethers.provider.getBlock(blockNumber);

  const start = block?.timestamp as number;
  const duration = 7 * 24 * 60 * 60;
  const delay = 7 * 24 * 60 * 60;

  const Staking = await hre.ethers.getContractFactory("StakingLinearVesting");
  const staking = await Staking.connect(contractOwner).deploy(mockStakingTokenAddress, mockRewardTokenAddress, start, duration, delay);
  await staking.waitForDeployment();
  const address = await staking.getAddress();

  return { mockStakingToken, mockRewardToken, staking, address };
}

export async function getTokensFromFaucet() {
  if (hre.network.name === "localfhenix") {
    const signers = await hre.ethers.getSigners();

    if (
      (await hre.ethers.provider.getBalance(signers[0].address)).toString() ===
      "0"
    ) {
      await hre.fhenixjs.getFunds(signers[0].address);
      await hre.fhenixjs.getFunds(signers[1].address);
      await hre.fhenixjs.getFunds(signers[2].address);
    }
  }
}
