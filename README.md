# Onboarding-Task

## **Task**: **Develop a Staking and Reward System Smart Contract**

### **Objective:**

You are tasked with developing a Solidity smart contract that allows users to deposit a specific ERC20 token into a staking pool. In return, users will earn rewards based on the amount they have staked and the duration of their staking period. The system will also include a penalty for early withdrawals and allow users to choose different reward tokens if available.

### **Key Components:**

1. **Staking Functionality:**
    - **User Deposits (Staking):** Users will be able to stake a certain amount of an ERC20 token (let's call it `StakingToken`) into the smart contract. When they stake, they must choose a reward token from a list of available reward tokens. The chosen reward token will be the one in which they receive their rewards.
    - **Stake Tracking:** The smart contract needs to keep track of each user's stake, including the amount staked, the time of the stake, and the selected reward token.
2. **Reward Distribution:**
    - **Reward Calculation:** The system will calculate rewards based on how long the tokens have been staked and how many tokens are staked. Rewards are distributed in the form of the reward token that the user selected during staking.
    - **Reward Distribution:** Rewards should claimable when user wishes to claim.
3. **Penalty for Early Withdrawals:**
    - **Early Withdrawal Penalty:** If a user decides to withdraw their staked tokens before a predefined minimum staking period (for example, 30 days), they will incur a penalty. The penalty is a percentage of the staked tokens, which will be deducted from the user's stake.
    - **Minimum Staking Period:** Define a minimum period that users must stake their tokens to avoid penalties.
4. **Flexible Reward Token Selection:**
    - **Multiple Reward Tokens:** Users should have the option to choose from a list of different reward tokens when they stake their tokens. For instance, if there are multiple reward tokens available (e.g., `RewardTokenA`, `RewardTokenB`), the user should be able to select the one they prefer to receive.
    - **Dynamic Reward Pool:** The reward pool needs to handle multiple tokens, ensuring that users receive rewards in their chosen token.
5. **Deployment on Forked Mainnet:**
    - **Deployment Scripts:** Write scripts to perform deployment process on local forked mainnet, including setting up the reward pools and initializing the staking mechanism. Perform user simulation via the script.
6. **Comprehensive Testing:**
    - **Testing with Foundry:** Use Foundry to write and run tests that simulate user interactions with the staking contract. The tests should cover:
        - Normal staking and reward claiming.
        - Early withdrawals and penalty applications.
        - Edge cases like staking the maximum allowed amount, withdrawing all staked tokens, and multiple users interacting with the contract simultaneously.
    - **Forked Mainnet Testing:** Run these tests on the forked mainnet to ensure that the contract behaves correctly in a realistic environment.

### **Expected Outcomes:**

- A fully functional Solidity contract that allows users to stake tokens, earn rewards, and withdraw their stakes with or without penalties based on the timing.
- Deployment scripts for easy setup on a forked mainnet.
- A set of robust tests that ensure the contract behaves as expected under various scenarios.

This task will help you develop a deep understanding of staking mechanisms, reward distribution, and the intricacies of smart contract deployment and testing in a realistic blockchain environment.

Bonus:

1. Forge coverate should be 90%+ for all 4 categories.
2. Deploy the smart contract on holesky testnet.
