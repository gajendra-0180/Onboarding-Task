const hre = require("hardhat");

async function main() {
    // We get the contract to deploy
    const StakingRewardSystem = await hre.ethers.getContractFactory("StakingRewardSystem");
    
    // Define the constructor arguments if any
    const stakingToken = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"; // Replace with your staking token address
    const rewardTokens = ["0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9", "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707"]; // Replace with reward token addresses

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
