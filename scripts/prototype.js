const { ethers, network } = require("hardhat");
const { expect } = require("chai");

let owner, user1, user2, user3;
let StakingRewardSystem, stakingRewardSystem;
let MockERC20, stakingToken, rewardToken1, rewardToken2, rewardToken3;

const YEAR_IN_SECONDS = 365 * 24 * 60 * 60;
const DAY_IN_SECONDS = 24 * 60 * 60;

const ether = (amount) => ethers.utils.parseEther(amount.toString());

const moveTime = async (seconds) => {
    await network.provider.send("evm_increaseTime", [seconds]);
    await network.provider.send("evm_mine");
    console.log(`Moved time by ${seconds} seconds`);
};

const deployContracts = async () => {
    console.log("Deploying contracts...");

    // Deploy mock ERC20 tokens
    MockERC20 = await ethers.getContractFactory("MockERC20");
    stakingToken = await MockERC20.deploy("Staking Token", "STK");
    rewardToken1 = await MockERC20.deploy("Reward Token 1", "RWD1");
    rewardToken2 = await MockERC20.deploy("Reward Token 2", "RWD2");
    rewardToken3 = await MockERC20.deploy("Reward Token 3", "RWD3");

    // Deploy StakingRewardSystem
    StakingRewardSystem = await ethers.getContractFactory("StakingRewardSystem");
    stakingRewardSystem = await StakingRewardSystem.deploy();
    await stakingRewardSystem.initialize(stakingToken.address, [rewardToken1.address, rewardToken2.address]);

    console.log("Contracts deployed");
};

const setupInitialBalances = async () => {
    console.log("Setting up initial balances...");
    
    await stakingToken.mint(user1.address, ether(100000));
    await stakingToken.mint(user2.address, ether(100000));
    await stakingToken.mint(user3.address, ether(100000));
    
    await rewardToken1.mint(stakingRewardSystem.address, ether(1000000));
    await rewardToken2.mint(stakingRewardSystem.address, ether(1000000));
    await rewardToken3.mint(stakingRewardSystem.address, ether(1000000));

    console.log("Initial balances set up");
};

const testStaking = async () => {
    console.log("\nTesting staking...");
    
    await stakingToken.connect(user1).approve(stakingRewardSystem.address, ether(10000));
    await stakingRewardSystem.connect(user1).stake(ether(5000), rewardToken1.address);
    console.log("User1 staked 5000 tokens for Reward Token 1");

    await stakingToken.connect(user2).approve(stakingRewardSystem.address, ether(20000));
    await stakingRewardSystem.connect(user2).stake(ether(10000), rewardToken2.address);
    console.log("User2 staked 10000 tokens for Reward Token 2");

    // Edge case: Attempt to stake 0 tokens
    await expect(
        stakingRewardSystem.connect(user1).stake(0, rewardToken1.address)
    ).to.be.revertedWith("InvalidAmount");

    // Edge case: Attempt to stake for non-existent reward token
    await expect(
        stakingRewardSystem.connect(user1).stake(ether(1000), ethers.constants.AddressZero)
    ).to.be.revertedWith("InvalidRewardToken");
};

const testEarlyWithdrawal = async () => {
    console.log("\nTesting early withdrawal...");
    
    await moveTime(15 * DAY_IN_SECONDS);
    
    await stakingRewardSystem.connect(user1).withdraw(ether(2000), rewardToken1.address);
    console.log("User1 withdrew 2000 tokens early");

    // Edge case: Attempt to withdraw more than staked
    await expect(
        stakingRewardSystem.connect(user2).withdraw(ether(15000), rewardToken2.address)
    ).to.be.revertedWith("WithdrawAmountExceedsStake");

    // Edge case: Attempt to withdraw 0 tokens
    await expect(
        stakingRewardSystem.connect(user1).withdraw(0, rewardToken1.address)
    ).to.be.revertedWith("InvalidAmount");
};

const testRewardClaiming = async () => {
    console.log("\nTesting reward claiming...");
    
    // Attempt to claim before minimum staking period
    await expect(
        stakingRewardSystem.connect(user1).claimReward(rewardToken1.address)
    ).to.be.revertedWith("CannotClaimRewardYet");

    await moveTime(16 * DAY_IN_SECONDS); // Move to just after minimum staking period
    
    await stakingRewardSystem.connect(user1).claimReward(rewardToken1.address);
    console.log("User1 claimed reward for Reward Token 1");

    // Edge case: Attempt to claim for non-existent reward token
    await expect(
        stakingRewardSystem.connect(user1).claimReward(ethers.constants.AddressZero)
    ).to.be.revertedWith("InvalidRewardToken");
};

const testAdminFunctions = async () => {
    console.log("\nTesting admin functions...");
    
    await stakingRewardSystem.connect(owner).setMinStakingPeriod(60);
    console.log("Minimum staking period set to 60 days");

    await stakingRewardSystem.connect(owner).setEarlyWithdrawalPenalty(200000);
    console.log("Early withdrawal penalty set to 20%");

    await stakingRewardSystem.connect(owner).setRewardRate(100000);
    console.log("Reward rate set to 10%");

    // Edge case: Non-owner attempting to call admin functions
    await expect(
        stakingRewardSystem.connect(user1).setMinStakingPeriod(30)
    ).to.be.revertedWith("Ownable: caller is not the owner");

    // Edge case: Setting invalid values
    await expect(
        stakingRewardSystem.connect(owner).setEarlyWithdrawalPenalty(1000001) // > 100%
    ).to.be.revertedWith("InvalidInput");
};

const testAddingNewRewardToken = async () => {
    console.log("\nTesting adding new reward token...");
    
    await stakingRewardSystem.connect(owner).addRewardToken(rewardToken3.address);
    console.log("Added Reward Token 3");

    // Edge case: Attempting to add the same reward token again
    await expect(
        stakingRewardSystem.connect(owner).addRewardToken(rewardToken3.address)
    ).to.be.revertedWith("InvalidRewardToken");

    // Test staking with new reward token
    await stakingToken.connect(user3).approve(stakingRewardSystem.address, ether(5000));
    await stakingRewardSystem.connect(user3).stake(ether(5000), rewardToken3.address);
    console.log("User3 staked 5000 tokens for Reward Token 3");
};

const testPenaltyWithdrawal = async () => {
    console.log("\nTesting penalty withdrawal...");
    
    const initialOwnerBalance = await stakingToken.balanceOf(owner.address);
    await stakingRewardSystem.connect(owner).withdrawPenalties();
    const finalOwnerBalance = await stakingToken.balanceOf(owner.address);
    
    console.log("Owner withdrew accumulated penalties:", finalOwnerBalance.sub(initialOwnerBalance).toString());

    // Edge case: Attempting to withdraw penalties when there are none
    await expect(
        stakingRewardSystem.connect(owner).withdrawPenalties()
    ).to.be.revertedWith("NoPenaltiesToWithdraw");
};

const testGetUserStakeData = async () => {
    console.log("\nTesting getUserStakeData...");
    
    const user1StakeData = await stakingRewardSystem.getUserStakeData(user1.address);
    console.log("User1 stake data:", user1StakeData);

    const user2StakeData = await stakingRewardSystem.getUserStakeData(user2.address);
    console.log("User2 stake data:", user2StakeData);

    const user3StakeData = await stakingRewardSystem.getUserStakeData(user3.address);
    console.log("User3 stake data:", user3StakeData);

    // Edge case: Getting stake data for user with no stakes
    await expect(
        stakingRewardSystem.getUserStakeData(ethers.constants.AddressZero)
    ).to.be.revertedWith("UserNotExist");
};

const testGetRewardTokens = async () => {
    console.log("\nTesting getRewardTokens...");
    
    const rewardTokens = await stakingRewardSystem.getRewardTokens();
    console.log("Reward tokens:", rewardTokens);
    expect(rewardTokens.length).to.equal(3);
};

const testGetStakedAmount = async () => {
    console.log("\nTesting getStakedAmount...");
    
    const user1StakedAmount = await stakingRewardSystem.getStakedAmount(user1.address, rewardToken1.address);
    console.log("User1 staked amount for Reward Token 1:", user1StakedAmount.toString());

    const user2StakedAmount = await stakingRewardSystem.getStakedAmount(user2.address, rewardToken2.address);
    console.log("User2 staked amount for Reward Token 2:", user2StakedAmount.toString());

    // Edge case: Getting staked amount for non-existent user/token combination
    await expect(
        stakingRewardSystem.getStakedAmount(ethers.constants.AddressZero, rewardToken1.address)
    ).to.be.revertedWith("UserNotExist");
};

const testComplexScenarios = async () => {
    console.log("\nTesting complex scenarios...");
    
    // Scenario 1: Multiple stakes and withdrawals
    await stakingToken.connect(user1).approve(stakingRewardSystem.address, ether(10000));
    await stakingRewardSystem.connect(user1).stake(ether(2000), rewardToken2.address);
    await stakingRewardSystem.connect(user1).stake(ether(3000), rewardToken3.address);
    console.log("User1 staked additional amounts in different reward tokens");

    await moveTime(40 * DAY_IN_SECONDS);

    await stakingRewardSystem.connect(user1).withdraw(ether(1000), rewardToken1.address);
    await stakingRewardSystem.connect(user1).withdraw(ether(500), rewardToken2.address);
    console.log("User1 performed partial withdrawals from multiple stakes");

    // Scenario 2: Staking more after claiming rewards
    await stakingRewardSystem.connect(user2).claimReward(rewardToken2.address);
    await stakingToken.connect(user2).approve(stakingRewardSystem.address, ether(5000));
    await stakingRewardSystem.connect(user2).stake(ether(5000), rewardToken2.address);
    console.log("User2 claimed rewards and staked more");
};

async function main() {
    [owner, user1, user2, user3] = await ethers.getSigners();
    
    await deployContracts();
    await setupInitialBalances();
    await testStaking();
    await testEarlyWithdrawal();
    await testRewardClaiming();
    await testAdminFunctions();
    await testAddingNewRewardToken();
    await testPenaltyWithdrawal();
    await testGetUserStakeData();
    await testGetRewardTokens();
    await testGetStakedAmount();
    await testComplexScenarios();

    console.log("\nAll tests completed successfully");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

// Mock ERC20 Token Contract
// const MockERC20 = `
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contract MockERC20 is ERC20 {
//     constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

//     function mint(address to, uint256 amount) public {
//         _mint(to, amount);
//     }
// }
// `;