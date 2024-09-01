// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/StakingRewardSystem.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}

contract StakingRewardSystemTest is Test {
    /* ============== Events ============== */

    event Staked(address indexed user, uint256 amount, address indexed rewardToken);
    event Withdrawn(address indexed user, uint256 amount, uint256 penalty, address indexed rewardToken);
    event RewardClaimed(address indexed user, uint256 rewardAmount, address indexed rewardToken);
    event PenaltiesWithdrawn(address indexed owner, uint256 amount);
    event RewardTokenAdded(address indexed rewardToken, address addedBy);
    event MinStakingPeriodUpdated(uint256 previousPeriod, uint256 newPeriod, address updatedBy);
    event EarlyWithdrawalPenaltyUpdated(uint256 previousPenalty, uint256 newPenalty, address updatedBy);
    event RewardRateUpdated(uint256 previousRate, uint256 newRate, address updatedBy);

    using SafeERC20 for IERC20;

    StakingRewardSystem public stakingRewardSystem;
    MockToken public stakingToken;
    MockToken public rewardToken1;
    MockToken public rewardToken2;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);

    uint256 public initialBalance = 1000 ether;
    uint256 public stakeAmount = 0.0000000000000002 ether;

    function setUp() public {
        // Deploy mock tokens
        stakingToken = new MockToken("Staking Token", "STK");
        rewardToken1 = new MockToken("Reward Token 1", "RT1");
        rewardToken2 = new MockToken("Reward Token 2", "RT2");

        // Mint tokens to users
        stakingToken.mint(user1, initialBalance);
        stakingToken.mint(user2, initialBalance);

        rewardToken1.mint(address(this), initialBalance);
        rewardToken2.mint(address(this), initialBalance);

        // Deploy StakingRewardSystem contract
        stakingRewardSystem = new StakingRewardSystem();
        address[] memory rewardTokens = new address[](2);
         rewardTokens[0] = address(rewardToken1);
         rewardTokens[1] = address(rewardToken2);
        // rewardToken1 = address(rewardToken1);
        // rewardToken2 = address(rewardToken2);
        stakingRewardSystem.initialize(address(stakingToken), rewardTokens);
        // stakingRewardSystem.initialize(address(stakingToken), address(rewardToken1));

           // Transfer ownership to the owner address
    vm.prank(stakingRewardSystem.owner());
        stakingRewardSystem.transferOwnership(owner);
    }

    function test_StakeAndEmitStakedEvent() public {
        vm.startPrank(user1);

        // Approve and stake tokens
        stakingToken.approve(address(stakingRewardSystem), stakeAmount);
        vm.expectEmit(true, true, true, true);
        emit Staked(user1, stakeAmount, address(rewardToken1));
        stakingRewardSystem.stake(stakeAmount, address(rewardToken1));

        // Check if the stake is recorded
            console.log("Approved stakeAmount:", stakeAmount);
        uint256 stakedAmount = stakingRewardSystem.getStakedAmount(user1, address(rewardToken1));
        assertEq(stakedAmount, stakeAmount);

        vm.stopPrank();
    }

//     function test_WithdrawBeforeMinStakingPeriod() public {
//         vm.startPrank(user1);

//         // Approve and stake tokens
//         stakingToken.approve(address(stakingRewardSystem), stakeAmount);
//         stakingRewardSystem.stake(stakeAmount, address(rewardToken1));

//         // Attempt to withdraw before the minimum staking period
//         vm.expectRevert(abi.encodeWithSelector(StakingRewardSystem.CannotClaimRewardYet.selector));
//         stakingRewardSystem.withdraw(stakeAmount, address(rewardToken1));

//         vm.stopPrank();
//     }

//     function test_WithdrawAfterMinStakingPeriod() public {
//         vm.startPrank(user1);

//         // Approve and stake tokens
//         stakingToken.approve(address(stakingRewardSystem), stakeAmount);
//         stakingRewardSystem.stake(stakeAmount, address(rewardToken1));

//         // Fast forward time beyond the minimum staking period
//         vm.warp(block.timestamp + 31 days);

//         // Withdraw after the minimum staking period
//         stakingRewardSystem.withdraw(stakeAmount, address(rewardToken1));

//         // Check if the balance is correct
//         uint256 balance = stakingToken.balanceOf(user1);
//         assertEq(balance, initialBalance);

//         vm.stopPrank();
//     }

//     function test_ClaimRewardAfterMinStakingPeriod() public {
//         vm.startPrank(user1);

//         // Approve and stake tokens
//         stakingToken.approve(address(stakingRewardSystem), stakeAmount);
//         stakingRewardSystem.stake(stakeAmount, address(rewardToken1));

//         // Fast forward time beyond the minimum staking period
//         vm.warp(block.timestamp + 31 days);

//         // Claim reward
//         uint256 initialRewardBalance = rewardToken1.balanceOf(user1);
//         stakingRewardSystem.claimReward(address(rewardToken1));

//         // Check if the reward was received
//         uint256 finalRewardBalance = rewardToken1.balanceOf(user1);
//         assertGt(finalRewardBalance, initialRewardBalance);

//         vm.stopPrank();
//     }

//     function test_WithdrawPenaltiesByOwner() public {
//         vm.startPrank(owner);

//         // Set penalty and staking parameters
//         stakingRewardSystem.setEarlyWithdrawalPenalty(100000);
//         stakingRewardSystem.setMinStakingPeriod(30);

//         vm.stopPrank();
//         vm.startPrank(user1);

//         // Stake and attempt to withdraw before the minimum staking period
//         stakingToken.approve(address(stakingRewardSystem), stakeAmount);
//         stakingRewardSystem.stake(stakeAmount, address(rewardToken1));

//         // Fast forward time just before the minimum staking period
//         vm.warp(block.timestamp + 15 days);

//         stakingRewardSystem.withdraw(stakeAmount, address(rewardToken1));

//         vm.stopPrank();
//         vm.startPrank(owner);

//         // Withdraw accumulated penalties
//         uint256 initialOwnerBalance = stakingToken.balanceOf(owner);
//         stakingRewardSystem.withdrawPenalties();

//         // Check if penalties were received
//         uint256 finalOwnerBalance = stakingToken.balanceOf(owner);
//         assertGt(finalOwnerBalance, initialOwnerBalance);

//         vm.stopPrank();
//     }

//     function test_ExpectRevertInvalidRewardToken() public {
//         vm.startPrank(user1);

//         // Attempt to stake with an invalid reward token
//         vm.expectRevert(abi.encodeWithSelector(StakingRewardSystem.InvalidRewardToken.selector));
//         stakingRewardSystem.stake(stakeAmount, address(0));

//         vm.stopPrank();
//     }
}
