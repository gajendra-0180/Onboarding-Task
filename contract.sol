pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract StakingRewardSystem is Ownable, ReentrancyGuard, PausableUpgradeable, Initializable {

    IERC20 public stakingToken;  // The token that users will stake

    // Structure to represent each stake
    struct Stake {
        uint256 amount;  // Amount of tokens staked
        uint256 startTime;  // Timestamp when the stake was created
    }
    
    uint256 public minStakingPeriod;  // Minimum period required to avoid early withdrawal penalties
    uint256 public earlyWithdrawalPenalty;  // Penalty percentage for early withdrawal (scaled to 1e18)
    uint256 public rewardRate;  // Rate at which rewards are calculated (scaled to 1e18)
    uint256 public accumulatedPenalties;  // Holds the total penalties accumulated (in token's smallest unit)

    address[] public rewardTokens;  // List of tokens available as rewards

    // Mapping to track each user's stakes based on the reward token they selected
    mapping(address => mapping(address => Stake)) public stakes;
    mapping(address => bool) public isRewardToken;  // Tracks if a token is a valid reward token

    // Events for logging key actions in the contract
    event Staked(address indexed user, uint256 amount, address indexed rewardToken);
    event Withdrawn(address indexed user, uint256 amount, uint256 penalty, address indexed rewardToken);
    event RewardClaimed(address indexed user, uint256 rewardAmount, address indexed rewardToken);
    event PenaltiesWithdrawn(address indexed owner, uint256 amount);

    // Custom errors for more efficient error handling
    error InvalidAmount();  // Thrown when staking amount is 0 or negative
    error InvalidRewardToken();  // Thrown when an invalid reward token is specified
    error WithdrawAmountExceedsStake();  // Thrown when trying to withdraw more than staked
    error NoStakeFound();  // Thrown when trying to claim reward without a stake
    error CannotClaimRewardYet();  // Thrown when attempting to claim reward too early
    error NoPenaltiesToWithdraw();  // Thrown when no penalties are available for withdrawal by the owner

    // Initializer function to replace constructor for upgradeable contracts
    function initialize(address _stakingToken, address[] memory _rewardTokens) public initializer {
        __Pausable_init();  // Initialize pausable functionality
        stakingToken = IERC20(_stakingToken);  // Set the staking token
        minStakingPeriod = 30;  // Set the minimum staking period
        earlyWithdrawalPenalty = 10 * 1e18;  // Set the early withdrawal penalty percentage, scaled to 1e18
        rewardRate = 1 * 1e18;  // Set the reward rate, scaled to 1e18

        // Add reward tokens and mark them as valid
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            rewardTokens.push(_rewardTokens[i]);
            isRewardToken[_rewardTokens[i]] = true;
        }
    }

    // Function to stake tokens
    function stake(uint256 amount, address rewardToken) external nonReentrant whenNotPaused {
        if (amount <= 0) revert InvalidAmount();  // Ensure amount is positive
        if (!isRewardToken[rewardToken]) revert InvalidRewardToken();  // Ensure reward token is valid

        stakingToken.transferFrom(msg.sender, address(this), amount);  // Transfer staked tokens to the contract

        Stake storage userStake = stakes[msg.sender][rewardToken];  // Access the user's stake for this reward token
        userStake.amount += amount;  // Update the staked amount
        userStake.startTime = block.timestamp;  // Record the start time of the stake

        emit Staked(msg.sender, amount, rewardToken);  // Emit a Staked event
    }

    // Function to withdraw staked tokens
    function withdraw(uint256 amount, address rewardToken) external nonReentrant whenNotPaused {
        Stake storage userStake = stakes[msg.sender][rewardToken];  // Access the user's stake for this reward token
        if (userStake.amount < amount) revert WithdrawAmountExceedsStake();  // Ensure the user has enough staked

        uint256 penalty = 0;
        // Check if the withdrawal is before the minimum staking period ends
        if (block.timestamp < userStake.startTime + minStakingPeriod) {
            penalty = (amount * earlyWithdrawalPenalty) / 1e20;  // Calculate penalty based on scaled value
            amount -= penalty;  // Subtract penalty from the amount to be withdrawn
            accumulatedPenalties += penalty;  // Add penalty to accumulated penalties
        }

        userStake.amount -= amount;  // Update the user's staked amount
        stakingToken.transfer(msg.sender, amount);  // Transfer the remaining amount to the user

        emit Withdrawn(msg.sender, amount, penalty, rewardToken);  // Emit a Withdrawn event
    }

    // Function to claim rewards based on staked tokens
    function claimReward(address rewardToken) external nonReentrant whenNotPaused {
        Stake storage userStake = stakes[msg.sender][rewardToken];  // Access the user's stake for this reward token
        if (userStake.amount == 0) revert NoStakeFound();  // Ensure the user has a stake
        if (block.timestamp <= userStake.startTime + minStakingPeriod) revert CannotClaimRewardYet();  // Ensure the minimum staking period has passed

        uint256 stakingDuration = block.timestamp - userStake.startTime;  // Calculate the staking duration
        uint256 rewardAmount = (userStake.amount * rewardRate * stakingDuration) / 1e18;  // Calculate the reward amount

        IERC20(rewardToken).transfer(msg.sender, rewardAmount);  // Transfer the reward tokens to the user

        userStake.startTime = block.timestamp;  // Reset the stake start time

        emit RewardClaimed(msg.sender, rewardAmount, rewardToken);  // Emit a RewardClaimed event
    }

    // Function for the contract owner to withdraw accumulated penalties
    function withdrawPenalties() external onlyOwner nonReentrant whenNotPaused {
        uint256 amountToWithdraw = accumulatedPenalties;  // Get the total accumulated penalties
        if (amountToWithdraw == 0) revert NoPenaltiesToWithdraw();  // Ensure there are penalties to withdraw

        accumulatedPenalties = 0;  // Reset the accumulated penalties
        stakingToken.transfer(owner(), amountToWithdraw);  // Transfer the penalties to the owner

        emit PenaltiesWithdrawn(owner(), amountToWithdraw);  // Emit a PenaltiesWithdrawn event
    }

    // Function to add a new reward token
    function addRewardToken(address rewardToken) external onlyOwner {
        if (isRewardToken[rewardToken]) revert InvalidRewardToken();  // Ensure the token is not already a reward token
        rewardTokens.push(rewardToken);  // Add the token to the reward tokens list
        isRewardToken[rewardToken] = true;  // Mark the token as a valid reward token
    }

    // Function to set the minimum staking period
    function setMinStakingPeriod(uint256 period) external onlyOwner {
        minStakingPeriod = period;
    }

    // Function to set the early withdrawal penalty percentage
    function setEarlyWithdrawalPenalty(uint256 penalty) external onlyOwner {
        earlyWithdrawalPenalty = penalty * 1e18;
    }

    // Function to set the reward rate
    function setRewardRate(uint256 rate) external onlyOwner {
        rewardRate = rate * 1e18;
    }

    // Function to get the list of reward tokens
    function getRewardTokens() external view returns (address[] memory) {
        return rewardTokens;
    }

    // Function to get the staked amount of a user for a specific reward token
    function getStakedAmount(address user, address rewardToken) external view returns (uint256) {
        if (!isRewardToken[rewardToken]) revert InvalidRewardToken();  // Ensure the reward token is valid
        Stake storage userStake = stakes[user][rewardToken];  // Access the user's stake
        return userStake.amount;  // Return the staked amount
    }
}
