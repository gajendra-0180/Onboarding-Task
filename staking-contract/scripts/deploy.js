const hre = require("hardhat");

async function main() {
    // We get the contract to deploy
    const StakingRewardSystem = await hre.ethers.getContractFactory("StakingRewardSystem");
    
    // Define the constructor arguments if any
    const stakingToken = "0xYourStakingTokenAddress"; // Replace with your staking token address
    const rewardTokens = ["0xYourRewardTokenAddress1", "0xYourRewardTokenAddress2"]; // Replace with reward token addresses

    const stakingRewardSystem = await StakingRewardSystem.deploy(stakingToken, rewardTokens);

    await stakingRewardSystem.deployed();

    console.log("StakingRewardSystem deployed to:", stakingRewardSystem.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
