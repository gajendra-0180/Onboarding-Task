const hre = require("hardhat");

async function main() {
  // Deploy the MyToken contract
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
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
