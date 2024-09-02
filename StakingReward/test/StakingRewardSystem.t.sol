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

    /* ============== Errors ============= */
    error InvalidAmount();
    error InvalidRewardToken();
    error WithdrawAmountExceedsStake();
    error NoStakeFound();
    error CannotClaimRewardYet();
    error NoPenaltiesToWithdraw();
    error InvalidInput(string message); 
    error UserNotExist();  


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
    uint256 public stakeAmount =1000 ether;

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
    function testSetMinStakingPeriodAsOwner() public {
        vm.prank(owner);
        stakingRewardSystem.setMinStakingPeriod(45);

        assertEq(stakingRewardSystem.minStakingPeriod(), 45 * 86400);
    }

    function testSetEarlyWithdrawalPenaltyAsOwner() public {
        vm.prank(owner);
        stakingRewardSystem.setEarlyWithdrawalPenalty(50000);

        assertEq(stakingRewardSystem.earlyWithdrawalPenalty(), 50000);
    }
     function testSetRewardRateAsOwner() public {
        vm.prank(owner);
        stakingRewardSystem.setRewardRate(90000);

        assertEq(stakingRewardSystem.rewardRate(), 90000);
    }
    function testSetRewardRateInvalidInput() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "Reward rate must be greater than zero"));
        stakingRewardSystem.setRewardRate(0);
    }

    //  function testWithdrawPenaltiesAsOwner() public {
    //     vm.startPrank(owner);
    //     stakingRewardSystem.setEarlyWithdrawalPenalty(100000); // Set penalty to 10%

    //     vm.startPrank(user1);
    //     stakingToken.approve(address(stakingRewardSystem), 1 );
    //     stakingRewardSystem.stake(1 , address(rewardToken1));

    //     // Fast forward time to trigger penalty
    //     vm.warp(block.timestamp + 1 days);
    //    vm.startPrank(user1);
    //     stakingRewardSystem.withdraw(1 , address(rewardToken1));

    //     uint256 accumulatedPenalty = stakingRewardSystem.accumulatedPenalties();
    //     assert(accumulatedPenalty > 0);

    //     vm.startPrank(owner);
    //     stakingRewardSystem.withdrawPenalties();

    //     assertEq(stakingToken.balanceOf(owner), accumulatedPenalty);
    //     assertEq(stakingRewardSystem.accumulatedPenalties(), 0);
    // }
    
    function testStake() public {
        vm.startPrank(user1);
        stakingToken.approve(address(stakingRewardSystem), 100 ether);
        stakingRewardSystem.stake(100 ether, address(rewardToken1));
        console.log("user1 amount:" , stakingToken.balanceOf(address(user1)));
        assertEq(stakingRewardSystem.getStakedAmount(user1, address(rewardToken1)), 100 ether);
        vm.stopPrank();
    }

        function testStakeWithInvalidAmount() public {
        vm.startPrank(user1);
        stakingToken.approve(address(stakingRewardSystem), 0);
        vm.expectRevert(InvalidAmount.selector);
        stakingRewardSystem.stake(0, address(rewardToken1));
        vm.stopPrank();
        }

        function testStakeWithInvalidRewardToken() public {
        vm.startPrank(user1);
        stakingToken.approve(address(stakingRewardSystem), 100 ether);
        vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "Reward token address cannot be zero"));
        stakingRewardSystem.stake(100 ether, address(0));
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(user1);
        stakingToken.approve(address(stakingRewardSystem), 100 ether);
        console.log(stakingToken.balanceOf(address(user1)));
        stakingRewardSystem.stake(100 ether, address(rewardToken1));
        console.log(stakingToken.balanceOf(address(user1)));
        vm.warp(block.timestamp + 30 days);
        stakingRewardSystem.withdraw(50 ether, address(rewardToken1));
        console.log(stakingToken.balanceOf(address(user1)));
        assertEq(stakingRewardSystem.getStakedAmount(user1, address(rewardToken1)), 50 ether);
        console.log(stakingToken.balanceOf(address(user1)));
        vm.stopPrank();
    }

        function testWithdrawExceedingStake() public {
        vm.startPrank(user1);
        stakingToken.approve(address(stakingRewardSystem), 100 ether);
        stakingRewardSystem.stake(100 ether, address(rewardToken1));
        vm.expectRevert(WithdrawAmountExceedsStake.selector);
        stakingRewardSystem.withdraw(150 ether, address(rewardToken1));
        vm.stopPrank();
    }

     function testClaimReward() public {
        vm.startPrank(user1);
        stakingToken.approve(address(stakingRewardSystem), 10 );
        stakingRewardSystem.stake(1 , address(rewardToken1));
        vm.warp(block.timestamp + 30 days);
        uint256 rewardAmount = stakingRewardSystem.getUserStakeData(user1)[0].rewardEarned;
        stakingRewardSystem.claimReward(address(rewardToken1));
        console.log(rewardAmount);
        assertEq(rewardToken1.balanceOf(user1), rewardAmount);
        vm.stopPrank();
    }

        function testClaimRewardBeforeMinStakingPeriod() public {
        vm.startPrank(user1);
        stakingToken.approve(address(stakingRewardSystem), 100 ether);
        stakingRewardSystem.stake(100 ether, address(rewardToken1));
        vm.expectRevert(CannotClaimRewardYet.selector);
        stakingRewardSystem.claimReward(address(rewardToken1));
        vm.stopPrank();
    }

    //     function testWithdrawPenalties() public {
    //     vm.startPrank(user1);
    //     stakingToken.approve(address(stakingRewardSystem), 100 );
    //     stakingRewardSystem.stake(100 , address(rewardToken1));
    //     vm.warp(block.timestamp + 15 days);
    //     stakingRewardSystem.withdraw(50 , address(rewardToken1));
    //     vm.stopPrank();

    //     uint256 accumulatedPenalties = stakingRewardSystem.accumulatedPenalties();
    //     vm.prank(owner);
    //     stakingRewardSystem.withdrawPenalties();
    //     assertEq(stakingToken.balanceOf(owner), accumulatedPenalties);
    // }

    function testGetUserStakeDataWithStakes() public {
        vm.startPrank(user1);
        stakingToken.approve(address(stakingRewardSystem), 100 ether);
        stakingRewardSystem.stake(100 ether, address(rewardToken1));
        console.log("user1 amount:" , stakingToken.balanceOf(address(user1)));
        stakingRewardSystem.getUserStakeData(user1);
    }
    function testGetUserStakeDataWithNoStakes() public {
        vm.expectRevert(UserNotExist.selector);
        stakingRewardSystem.getUserStakeData(user1);
    }

    function testGetRewardTokens() public {
        stakingRewardSystem.getRewardTokens();
    }

       function testGetUserStakeData() public {
        vm.startPrank(user1);
        stakingToken.approve(address(stakingRewardSystem), 100 );
        stakingRewardSystem.stake(100 , address(rewardToken1));
        vm.warp(block.timestamp + 30 );
        StakingRewardSystem.Stake[] memory stakeData = stakingRewardSystem.getUserStakeData(user1);
        assertEq(stakeData.length, 1);
        assertEq(stakeData[0].amount, 100 );
        vm.stopPrank();
    }

     function testAddRewardToken() public {
        vm.startPrank(owner);
        MockToken rewardToken3 = new MockToken("Reward Token 2", "RT2");
        stakingRewardSystem.addRewardToken(address(rewardToken3));

        assertTrue(stakingRewardSystem.isRewardToken(address(rewardToken3)));
        vm.stopPrank();
    }

    function testAdminFunctions() public {
        vm.startPrank(owner);

        // Set new minimum staking period
        stakingRewardSystem.setMinStakingPeriod(60);
        assertEq(stakingRewardSystem.minStakingPeriod(), 60 * 86400);

        // Set new early withdrawal penalty
        stakingRewardSystem.setEarlyWithdrawalPenalty(200000);
        assertEq(stakingRewardSystem.earlyWithdrawalPenalty(), 200000);

        // Set new reward rate
        stakingRewardSystem.setRewardRate(80000);
        assertEq(stakingRewardSystem.rewardRate(), 80000);

        vm.stopPrank();
    }
}
