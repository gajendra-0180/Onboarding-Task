const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StakingRewardSystem", function () {
  let stakingToken, rewardToken, StakingRewardSystem, stakingSystem;
  let owner, user1, user2, anotherRewardToken;

  before(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy mock ERC20 token for staking
    const Token = await ethers.getContractFactory("ERC20Mock");
    stakingToken = await Token.deploy("Staking Token", "STK", ethers.utils.parseEther("1000000"));
    rewardToken = await Token.deploy("Reward Token", "RWD", ethers.utils.parseEther("500000"));
    anotherRewardToken = await Token.deploy("Another Reward Token", "ARWD", ethers.utils.parseEther("300000"));

    // Deploy the StakingRewardSystem
    const StakingRewardSystem = await ethers.getContractFactory("StakingRewardSystem");
    stakingSystem = await upgrades.deployProxy(StakingRewardSystem, [stakingToken.address, [rewardToken.address]], { initializer: 'initialize' });
  });

  describe("Initialization", function () {
    it("should set initial parameters correctly", async function () {
      expect(await stakingSystem.stakingToken()).to.equal(stakingToken.address);
      expect(await stakingSystem.rewardTokens(0)).to.equal(rewardToken.address);
      expect(await stakingSystem.minStakingPeriod()).to.equal(30 * 86400);
    });
  });

  describe("Staking Operations", function () {
    it("should allow users to stake tokens", async function () {
      const stakeAmount = ethers.utils.parseEther("1000");
      await stakingToken.connect(user1).approve(stakingSystem.address, stakeAmount);
      await stakingSystem.connect(user1).stake(stakeAmount, rewardToken.address);
      
      const userStake = await stakingSystem.getStakedAmount(user1.address, rewardToken.address);
      expect(userStake).to.equal(stakeAmount);
    });

    it("should apply penalties if withdrawn early", async function () {
      const withdrawAmount = ethers.utils.parseEther("500");
      await ethers.provider.send("evm_increaseTime", [15 * 86400]); // Fast forward time by 15 days
      await stakingSystem.connect(user1).withdraw(withdrawAmount, rewardToken.address);
      
      const penalties = await stakingSystem.accumulatedPenalties();
      expect(penalties).to.be.gt(0);
    });
  });

  describe("Reward Claiming", function () {
    it("should allow users to claim rewards after the staking period", async function () {
      await ethers.provider.send("evm_increaseTime", [30 * 86400]); // Fast forward to exceed min staking period
      await stakingSystem.connect(user1).claimReward(rewardToken.address);
    });
  });

  describe("Administrative Functions", function () {
    it("should allow the owner to set the minimum staking period", async function () {
      const newMinStakingPeriod = 60 * 86400; // 60 days
      await stakingSystem.connect(owner).setMinStakingPeriod(60);
      expect(await stakingSystem.minStakingPeriod()).to.equal(newMinStakingPeriod);
    });

    it("should allow the owner to set the early withdrawal penalty", async function () {
      const newPenalty = ethers.utils.parseUnits("5", 5); // 0.05%
      await stakingSystem.connect(owner).setEarlyWithdrawalPenalty(newPenalty);
      expect(await stakingSystem.earlyWithdrawalPenalty()).to.equal(newPenalty);
    });

    it("should allow the owner to set the reward rate", async function () {
      const newRewardRate = ethers.utils.parseUnits("1", 4); // 0.01%
      await stakingSystem.connect(owner).setRewardRate(newRewardRate);
      expect(await stakingSystem.rewardRate()).to.equal(newRewardRate);
    });

    it("should allow the owner to add a new reward token", async function () {
      await stakingSystem.connect(owner).addRewardToken(anotherRewardToken.address);
      expect(await stakingSystem.isRewardToken(anotherRewardToken.address)).to.be.true;
    });

    it("should allow the owner to withdraw penalties", async function () {
      await stakingSystem.connect(owner).withdrawPenalties();
      expect(await stakingSystem.accumulatedPenalties()).to.equal(0);
    });
  });

  describe("Getter Functions", function () {
    it("should return the correct list of reward tokens", async function () {
      const tokens = await stakingSystem.getRewardTokens();
      expect(tokens).to.include.members([rewardToken.address, anotherRewardToken.address]);
    });

    it("should provide all staking data for a user", async function () {
      const data = await stakingSystem.getUserStakeData(user1.address);
      expect(data.length).to.be.gt(0);
      data.forEach(stake => {
        expect(stake.amount).to.be.gt(0);
      });
    });
  });
});
