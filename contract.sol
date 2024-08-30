pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract StakingRewardSystem is Ownable, ReentrancyGuard, PausableUpgradeable, Initializable {
    // The token that users will stake
    IERC20 public stakingToken;

    // Represents each stake by the user
    struct Stake {
        uint256 amount;  // Amount of tokens staked
        uint256 startTime;  // Timestamp when the stake was created
        uint256 rewardEarned;  // Reward earned so far
    }

    // Contract configuration variables
    uint256 public minStakingPeriod;
    uint256 public earlyWithdrawalPenalty;
    uint256 public rewardRate;
    uint256 public accumulatedPenalties;

    // List of reward tokens
    address[] public rewardTokens;
    mapping(address => bool) public isRewardToken;

    // Maps user addresses to their stakes by reward token
    mapping(address => mapping(address => Stake)) private userStakes;

    // Events for logging important contract actions
    event Staked(address indexed user, uint256 amount, address indexed rewardToken);
    event Withdrawn(address indexed user, uint256 amount, uint256 penalty, address indexed rewardToken);
    event RewardClaimed(address indexed user, uint256 rewardAmount, address indexed rewardToken);
    event PenaltiesWithdrawn(address indexed owner, uint256 amount);
    event RewardTokenAdded(address indexed rewardToken, address addedBy);
    event MinStakingPeriodUpdated(uint256 previousPeriod, uint256 newPeriod, address updatedBy);
    event EarlyWithdrawalPenaltyUpdated(uint256 previousPenalty, uint256 newPenalty, address updatedBy);
    event RewardRateUpdated(uint256 previousRate, uint256 newRate, address updatedBy);

    // Custom errors for more efficient error handling
    error InvalidAmount();
    error InvalidRewardToken();
    error WithdrawAmountExceedsStake();
    error NoStakeFound();
    error CannotClaimRewardYet();
    error NoPenaltiesToWithdraw();

    // Initializer function to replace constructor for upgradeable contracts
    function initialize(address _stakingToken, address[] memory _rewardTokens) public initializer {
        __Pausable_init();
        stakingToken = IERC20(_stakingToken);
        minStakingPeriod = 30 *86400;
        earlyWithdrawalPenalty = 1e16;
        rewardRate = 1 * 1e18;

        _addRewardTokens(_rewardTokens);
    }

    // Internal function to add multiple reward tokens during initialization
    function _addRewardTokens(address[] memory _rewardTokens) internal {
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            _addRewardToken(_rewardTokens[i]);
        }
    }

    // Pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    // Unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    // Function to stake tokens
    function stake(uint256 amount, address rewardToken) external nonReentrant whenNotPaused {
        _validateStake(amount, rewardToken);
        stakingToken.transferFrom(msg.sender, address(this), amount);
        _updateStake(msg.sender, rewardToken, amount);
        emit Staked(msg.sender, amount, rewardToken);
    }

    // Internal function to validate staking parameters
    function _validateStake(uint256 amount, address rewardToken) internal view {
        if (amount <= 0) revert InvalidAmount();
        if (!isRewardToken[rewardToken]) revert InvalidRewardToken();
    }

    // Internal function to update the user's stake
    function _updateStake(address user, address rewardToken, uint256 amount) internal {
        Stake storage userStake = userStakes[user][rewardToken];
        userStake.amount += amount;
        userStake.startTime = block.timestamp;
    }

    // Function to withdraw staked tokens
    function withdraw(uint256 amount, address rewardToken) external nonReentrant whenNotPaused {
        Stake storage userStake = userStakes[msg.sender][rewardToken];
        _validateWithdraw(userStake, amount);

        uint256 penalty = _applyEarlyWithdrawalPenalty(userStake, amount);
        userStake.amount -= amount;
        stakingToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount, penalty, rewardToken);
    }

    // Internal function to validate the withdrawal request
    function _validateWithdraw(Stake storage userStake, uint256 amount) internal view {
        if (userStake.amount < amount) revert WithdrawAmountExceedsStake();
    }

    // Internal function to apply the early withdrawal penalty if needed
    function _applyEarlyWithdrawalPenalty(Stake storage userStake, uint256 amount) internal returns (uint256) {
        uint256 penalty = 0;
        if (block.timestamp < userStake.startTime + minStakingPeriod) {
            penalty = (amount * earlyWithdrawalPenalty) / 1e18;
            amount -= penalty;
            accumulatedPenalties += penalty;
        }
        return penalty;
    }

    // Function to claim rewards based on staked tokens
    function claimReward(address rewardToken) external nonReentrant whenNotPaused {
        Stake storage userStake = userStakes[msg.sender][rewardToken];
        _validateClaim(userStake);

        uint256 rewardAmount = _calculateReward(userStake);
        IERC20(rewardToken).transfer(msg.sender, rewardAmount);
        userStake.startTime = block.timestamp;
        emit RewardClaimed(msg.sender, rewardAmount, rewardToken);
    }

    // Internal function to validate the reward claim
    function _validateClaim(Stake storage userStake) internal view {
        if (userStake.amount == 0) revert NoStakeFound();
        if (block.timestamp <= userStake.startTime + minStakingPeriod) revert CannotClaimRewardYet();
    }

    // Internal function to calculate the reward based on staking duration
    function _calculateReward(Stake storage userStake) internal view returns (uint256) {
        uint256 stakingDuration = block.timestamp - userStake.startTime;
        return (userStake.amount * rewardRate * stakingDuration) / 1e18;
    }

    // Function for the contract owner to withdraw accumulated penalties
    function withdrawPenalties() external onlyOwner nonReentrant whenNotPaused {
        uint256 amountToWithdraw = accumulatedPenalties;
        if (amountToWithdraw == 0) revert NoPenaltiesToWithdraw();

        accumulatedPenalties = 0;
        stakingToken.transfer(owner(), amountToWithdraw);
        emit PenaltiesWithdrawn(owner(), amountToWithdraw);
    }

    // Function to add a new reward token
    function addRewardToken(address rewardToken) external onlyOwner {
        _addRewardToken(rewardToken);
    }

    // Internal function to add a reward token and mark it as valid
    function _addRewardToken(address rewardToken) internal {
        if (isRewardToken[rewardToken]) revert InvalidRewardToken();
        rewardTokens.push(rewardToken);
        isRewardToken[rewardToken] = true;
        emit RewardTokenAdded(rewardToken, msg.sender);
    }

    // Function to set the minimum staking period
    function setMinStakingPeriod(uint256 period) external onlyOwner {
        emit MinStakingPeriodUpdated(minStakingPeriod, period*86400, msg.sender);
        minStakingPeriod = period*86400;
    }

    // Function to set the early withdrawal penalty percentage
    function setEarlyWithdrawalPenalty(uint256 penalty) external onlyOwner {
        emit EarlyWithdrawalPenaltyUpdated(earlyWithdrawalPenalty, penalty, msg.sender);
        earlyWithdrawalPenalty = penalty * 1e18;
    }

    // Function to set the reward rate
    function setRewardRate(uint256 rate) external onlyOwner {
        emit RewardRateUpdated(rewardRate, rate, msg.sender);
        rewardRate = rate;
    }

    // Function to get the list of reward tokens
    function getRewardTokens() external view returns (address[] memory) {
        return rewardTokens;
    }

    // Function to get the staked amount of a user for a specific reward token
    function getStakedAmount(address user, address rewardToken) external view returns (uint256) {
        if (!isRewardToken[rewardToken]) revert InvalidRewardToken();
        return userStakes[user][rewardToken].amount;
    }

    // Function to get all staking data for a user, including the amount staked and the rewards earned
    function getUserStakeData(address user) external view returns (Stake[] memory) {
        uint256 tokenCount = rewardTokens.length;
        Stake[] memory stakesData = new Stake[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            address rewardToken = rewardTokens[i];
            Stake storage userStake = userStakes[user][rewardToken];
            stakesData[i] = Stake({
                amount: userStake.amount,
                startTime: userStake.startTime,
                rewardEarned: _calculateReward(userStake)
            });
        }

        return stakesData;
    }
}
