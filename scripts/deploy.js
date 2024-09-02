// // const hre = require("hardhat");
// const { ethers, upgrades } = require("hardhat");
// async function main() {
//     const [deployer] = await ethers.getSigners();
//     // We get the contract to deploy
//     // const StakingRewardSystem = await hre.ethers.getContractFactory("StakingRewardSystem");

//     // Define the constructor arguments if any
//     // const stakingToken = "0xYourStakingTokenAddress"; // Replace with your staking token address
//     // const rewardTokens = ["0xYourRewardTokenAddress1", "0xYourRewardTokenAddress2"]; // Replace with reward token addresses
//     const stakingToken = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"; // Replace with your staking token address
//     const rewardTokens = ["0x70997970C51812dc3A010C7d01b50e0d17dc79C8", "0x90F79bf6EB2c4f870365E785982E1f101E93b906"]; // Replace with reward token addresses

//     // const stakingRewardSystem = await StakingRewardSystem.deploy(stakingToken, rewardTokens);

//     // await stakingRewardSystem.deployed();

//   const StakingRewardSystem = await ethers.getContractFactory("StakingRewardSystem");
// //   const stakingRewardSystem = await upgrades.deployProxy(StakingRewardSystem, [stakingToken, rewardTokens]);
// //   await stakingRewardSystem.deployed();
// const stakingRewardSystem = await StakingRewardSystem.deploy(stakingToken, rewardTokens);

// await stakingRewardSystem.deployed();

//     console.log("StakingRewardSystem deployed to:", stakingRewardSystem.address);
// }
// // We recommend this pattern to be able to use async/await everywhere
// // and properly handle errors.
// main().catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
// Import ethers from Hardhat package
const { ethers, upgrades } = require("hardhat");

async function main() {
    const StakingRewardSystem = await ethers.getContractFactory("StakingRewardSystem");
    const stakingToken = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"; // Replace with actual staking token address
    const rewardTokens = [
        "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9", // Replace with actual reward token addresses
        "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707"
    ];

    // Deploy using the proxy pattern and initialize in one step
    const stakingRewardSystem = await upgrades.deployProxy(
        StakingRewardSystem,
        [stakingToken, rewardTokens],
        { initializer: 'initialize' }
    );
    await stakingRewardSystem.deployed();

    console.log("StakingRewardSystem deployed to:", stakingRewardSystem.address);
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
