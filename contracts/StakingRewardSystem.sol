// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingRewardSystem is Initializable,OwnableUpgradeable {
    using SafeERC20 for IERC20;

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
    uint256 public constant DENOMINATOR=1000000;

    // List of reward tokens
    address[] public rewardTokens;
    mapping(address => bool) public isRewardToken;

    // Maps user addresses to their stakes by reward token
    mapping(address => mapping(address => Stake)) private userStakes;

/* ============ Constructor ============ */
    // constructor() {
    //     // _disableInitializers();
    // }

/* ============== Events ============== */

    event Staked(address indexed user, uint256 amount, address indexed rewardToken);
    event Withdrawn(address indexed user, uint256 amount, uint256 penalty, address indexed rewardToken);
    event RewardClaimed(address indexed user, uint256 rewardAmount, address indexed rewardToken);
    event PenaltiesWithdrawn(address indexed owner, uint256 amount);
    event RewardTokenAdded(address indexed rewardToken, address addedBy);
    event MinStakingPeriodUpdated(uint256 previousPeriod, uint256 newPeriod, address updatedBy);
    event EarlyWithdrawalPenaltyUpdated(uint256 previousPenalty, uint256 newPenalty, address updatedBy);
    event RewardRateUpdated(uint256 previousRate, uint256 newRate, address updatedBy);


/* ============== Errors ============= */
    error InvalidAmount();
    error InvalidRewardToken();
    error WithdrawAmountExceedsStake();
    error NoStakeFound();
    error CannotClaimRewardYet();
    error NoPenaltiesToWithdraw();
    error InvalidInput(string message); 
    error UserNotExist();  

/* ============== Initializer ============== */
    
    // Initializer function to replace constructor for upgradeable contracts
    function initialize(address _stakingToken, address[] memory _rewardTokens) public initializer {
        if (_rewardTokens.length == 0) revert InvalidInput("At least one reward token must be provided");
        if (_stakingToken == address(0)) revert InvalidInput("Staking token address cannot be zero");
        // __Ownable_init();
        // __Pausable_init();
        stakingToken = IERC20(_stakingToken);

        minStakingPeriod = 30 * 86400;
        earlyWithdrawalPenalty = 100000;
        rewardRate = 70000;

        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            _addRewardToken(_rewardTokens[i]);
        }
    }

/********************** ADMIN FUNCTIONS **********************/

    // // Pause the contract
    // function pause() external onlyOwner {
    //     _pause();
    // }

    // // Unpause the contract
    // function unpause() external onlyOwner {
    //     _unpause();
    // }

    // Function for the contract owner to withdraw accumulated penalties
    function withdrawPenalties() external onlyOwner {
        uint256 amountToWithdraw = accumulatedPenalties;
        if (amountToWithdraw <= 0) revert NoPenaltiesToWithdraw();

        accumulatedPenalties = 0;
        stakingToken.safeTransfer(owner(), amountToWithdraw);
        emit PenaltiesWithdrawn(owner(), amountToWithdraw);
    }

    // Function to add a new reward token
    function addRewardToken(address _rewardToken) external onlyOwner {
        _addRewardToken(_rewardToken);
    }

    // Function to set the minimum staking period
    function setMinStakingPeriod(uint256 _period) external onlyOwner {
        if (_period <= 0) revert InvalidInput("Minimum staking period must be greater than zero");
        uint256 prevminStakingPeriod=minStakingPeriod;
        minStakingPeriod = _period*86400;
        emit MinStakingPeriodUpdated(prevminStakingPeriod,minStakingPeriod, msg.sender);
    }

    // Function to set the early withdrawal penalty percentage
    function setEarlyWithdrawalPenalty(uint256 _penalty) external onlyOwner {
        if (_penalty <= 0 || _penalty > 1e18) revert InvalidInput("Penalty must be between 0 and 100%");
        uint256 prevPenalty=earlyWithdrawalPenalty;
        earlyWithdrawalPenalty = _penalty;
        emit EarlyWithdrawalPenaltyUpdated(prevPenalty, earlyWithdrawalPenalty, msg.sender);
    }

    // Function to set the reward rate
    function setRewardRate(uint256 _rate) external onlyOwner {
        if (_rate <= 0) revert InvalidInput("Reward rate must be greater than zero");
        uint256 preRewardRate=rewardRate;
        rewardRate = _rate;
        emit RewardRateUpdated(preRewardRate, rewardRate, msg.sender);
    }

    
/****************** Internal FUNCTIONS  ******************/ 

     // Function to validate common conditions
    function _validateStakingParameters(uint256 _amount, address _rewardToken) internal view {
        if (_amount <= 0) revert InvalidAmount();
        if (_rewardToken == address(0)) revert InvalidInput("Reward token address cannot be zero");
        if (!isRewardToken[_rewardToken]) revert InvalidRewardToken();
    }

    // Internal function to calculate the reward based on staking duration
    function _calculateReward(Stake memory userStake) internal view returns (uint256) {
        uint256 stakingDuration = block.timestamp - userStake.startTime;
        return (userStake.amount * rewardRate/(DENOMINATOR*365*24*86400) * stakingDuration) ;
    }



    // Internal function to add a reward token and mark it as valid
    function _addRewardToken(address _rewardToken) internal {
        if (_rewardToken == address(0)) revert InvalidInput("Reward token address cannot be zero");
        if (isRewardToken[_rewardToken]) revert InvalidRewardToken();
        rewardTokens.push(_rewardToken);
        isRewardToken[_rewardToken] = true;
        emit RewardTokenAdded(_rewardToken, msg.sender);
    }
    // Internal function to validate reward token and user stake
    function _validateRewardTokenAndStake(address _user, address _rewardToken) internal view returns (Stake storage) {
    if (_rewardToken == address(0)) revert InvalidInput("Reward token address cannot be zero");
    if (!isRewardToken[_rewardToken]) revert NoStakeFound();
    Stake storage userStake = userStakes[_user][_rewardToken];
    if (userStake.amount <= 0) revert UserNotExist();
    return userStake;
    }

/****************** EXTERNAL FUNCTIONS  ******************/


    // Function to stake tokens
    function stake(uint256 _amount, address _rewardToken) external   {
        _validateStakingParameters(_amount, _rewardToken);
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
        Stake storage userStake = userStakes[msg.sender][_rewardToken];
        userStake.amount += _amount;
        userStake.startTime = block.timestamp;
        emit Staked(msg.sender, _amount, _rewardToken);
    }

    // Function to withdraw staked tokens
    function withdraw(uint256 _amount, address _rewardToken) external {
        _validateStakingParameters(_amount, _rewardToken);
        Stake storage userStake = userStakes[msg.sender][_rewardToken];

        uint256 penalty = 0;
        if (block.timestamp < userStake.startTime + minStakingPeriod) {
            penalty = _amount * (earlyWithdrawalPenalty/(DENOMINATOR));
            if(_amount>userStake.amount) revert WithdrawAmountExceedsStake();
            _amount -= penalty;
            accumulatedPenalties += penalty;
        }
        userStake.amount=userStake.amount-_amount-penalty;
        stakingToken.safeTransfer(msg.sender, _amount); 
        emit Withdrawn(msg.sender, _amount, penalty, _rewardToken);
    }

  
    // Function to claim rewards based on staked tokens
    function claimReward(address _rewardToken) external  {
        Stake storage userStake = _validateRewardTokenAndStake(msg.sender, _rewardToken);
        if (block.timestamp < userStake.startTime + minStakingPeriod) revert CannotClaimRewardYet();

        uint256 rewardAmount = _calculateReward(userStake);
        IERC20(_rewardToken).safeTransfer(msg.sender, rewardAmount);
        userStake.startTime = block.timestamp;
        emit RewardClaimed(msg.sender, rewardAmount, _rewardToken);
    }



    // Function to get the list of reward tokens
    function getRewardTokens() external view returns (address[] memory) {
        return rewardTokens;
    }

    // Function to get the staked amount of a user for a specific reward token
    function getStakedAmount(address _user, address _rewardToken) external view returns (uint256) {
       Stake storage userStake = _validateRewardTokenAndStake(_user, _rewardToken);
       return userStake.amount;
    }

    // Function to get all staking data for a user, including the amount staked and the rewards earned
  function getUserStakeData(address _user) external view returns (Stake[] memory) {
    uint256 tokenCount = rewardTokens.length;
    uint256 nonZeroStakesCount = 0;

    // First, calculate how many non-zero stakes the user has
    for (uint256 i = 0; i < tokenCount; i++) {
        address rewardToken = rewardTokens[i];
        if (userStakes[_user][rewardToken].amount > 0) {
            nonZeroStakesCount++;
        }
    }

    // If the user has no stakes, revert
    if (nonZeroStakesCount <= 0) revert UserNotExist();

    // Now, create the array with the correct size
    Stake[] memory stakesData = new Stake[](nonZeroStakesCount);
    uint256 index = 0;

    // Populate the array with non-zero stakes
    for (uint256 i = 0; i < tokenCount; i++) {
        address rewardToken = rewardTokens[i];
        Stake storage userStake = userStakes[_user][rewardToken];
        if (userStake.amount > 0) {
            stakesData[index] = Stake({
                amount: userStake.amount,
                startTime: userStake.startTime,
                rewardEarned: _calculateReward(userStake)
            });
            index++;
        }
    }

    return stakesData;
    }
    
}
