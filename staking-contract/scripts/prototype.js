const hre = require("hardhat");

async function main() {
  const [deployer, user1, user2] = await hre.ethers.getSigners();

  // Log the addresses for confirmation
  console.log("Deployer address:", deployer.address);
  console.log("User1 address:", user1.address);
  console.log("User2 address:", user2.address);

  // Deploy the MyToken contract (assuming you've deployed these tokens)
  const MyToken = await hre.ethers.getContractFactory("MyToken");

  // Deploy a staking token
  const stakingToken = await MyToken.deploy("Staking Token", "STK", hre.ethers.utils.parseUnits("1000000", 18));
  await stakingToken.deployed();
  console.log("Staking Token deployed to:", stakingToken.address);

  // Deploy reward tokens
  const rewardToken1 = await MyToken.deploy("Reward Token 1", "RT1", hre.ethers.utils.parseUnits("1000000", 18));
  await rewardToken1.deployed();
  console.log("Reward Token 1 deployed to:", rewardToken1.address);

  const rewardToken2 = await MyToken.deploy("Reward Token 2", "RT2", hre.ethers.utils.parseUnits("1000000", 18));
  await rewardToken2.deployed();
  console.log("Reward Token 2 deployed to:", rewardToken2.address);

  const stakingRewardSystem = await hre.ethers.getContractFactory("StakingRewardSystem");
  const stakingRewardSystemInstance = await stakingRewardSystem.deploy();
  await stakingRewardSystemInstance.deployed();
  console.log("StakingRewardSystem deployed to:", stakingRewardSystemInstance.address);

  // Initialize the contract with staking and reward tokens
  await stakingRewardSystemInstance.initialize(stakingToken.address, [rewardToken1.address, rewardToken2.address]);
  console.log("StakingRewardSystem initialized with staking token and reward tokens");

  // User1 approves the staking contract to spend their tokens
  const stakeAmount = hre.ethers.utils.parseUnits("100.0", 18); // 100 tokens with 18 decimals
  await stakingToken.connect(user1).approve(stakingRewardSystemInstance.address, stakeAmount);
  console.log(`User1 approved ${stakeAmount.toString()} tokens`);

  // User1 stakes tokens
  await stakingRewardSystemInstance.connect(user1).stake(stakeAmount, rewardToken1.address);
  console.log(`User1 (${user1.address}) staked ${stakeAmount.toString()} tokens`);

  // Check staked amount for user1
  const stakedAmount = await stakingRewardSystemInstance.getStakedAmount(user1.address, rewardToken1.address);
  console.log(`User1 (${user1.address}) has staked ${stakedAmount.toString()} tokens`);

  // Fast-forward time by 31 days and claim rewards
  await hre.network.provider.send("evm_increaseTime", [3600 * 24 * 31]); // Fast forward 31 days
  await hre.network.provider.send("evm_mine"); // Mine a block to reflect the time change
  await stakingRewardSystemInstance.connect(user1).claimReward(rewardToken1.address);
  console.log("User1 claimed rewards");

  // Withdrawing staked tokens by user1
  await stakingRewardSystemInstance.connect(user1).withdraw(stakeAmount, rewardToken1.address);
  console.log("User1 withdrew tokens");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
