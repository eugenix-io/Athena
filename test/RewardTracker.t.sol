// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/RewardDistributor.sol";
import "../src/RewardTracker.sol";
import "../libraries/open-zeppelin/ERC20.sol";

contract RewardToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Mock ERC20 Token", "MCK") {
        _mint(msg.sender, initialSupply);
    }
}

contract DepositToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Mock ERC20 Token", "MCK") {
        _mint(msg.sender, initialSupply);
    }
}

contract RewardTrackerTest is Test {
    RewardDistributor rewardDistributor;
    RewardTracker rewardTracker;
    RewardToken rewardToken;
    DepositToken depositToken;
    address accountA;
    address accountB;
    address gov = address(this);

    function setUp() public{
        accountA = address(1001);
        accountB = address(1002);
        rewardToken = new RewardToken(1e24);
        depositToken = new DepositToken(1e24);
        rewardTracker = new RewardTracker('LogX Token', 'LOGX');
        rewardDistributor = new RewardDistributor(address(rewardToken), address(rewardTracker));
        address[] memory depositTokens = new address[](1);
        depositTokens[0] = address(depositToken);
        rewardTracker.initialize(depositTokens, address(rewardDistributor));
        depositToken.transfer(accountB, 100);
        depositToken.transfer(accountA, 100);
    }

    function testSetDepositToken() public {
        vm.prank(gov);
        rewardTracker.setDepositToken(address(depositToken), true);
        assertTrue(rewardTracker.isDepositToken(address(depositToken)));
    }

    function testFailSetDepositTokenByNonGov() public {
        address nonGov = address(0xBEEF);
        
        vm.prank(nonGov);
        rewardTracker.setDepositToken(address(depositToken), true);
    }

    function testSetInPrivateTransferMode() public {
        vm.prank(gov);
        rewardTracker.setInPrivateTransferMode(true);
        assertTrue(rewardTracker.inPrivateTransferMode());
    }

    function testSetInPrivateStakingMode() public {
        vm.prank(gov);
        rewardTracker.setInPrivateStakingMode(true);
        assertTrue(rewardTracker.inPrivateStakingMode());
    }

    function testSetInPrivateClaimingMode() public {
        vm.prank(gov);
        rewardTracker.setInPrivateClaimingMode(true);
        assertTrue(rewardTracker.inPrivateClaimingMode());
    }

    function testSetHandler() public {
        vm.prank(gov);
        address handlerMock = address(150);
        rewardTracker.setHandler(handlerMock, true);
        assertTrue(rewardTracker.isHandler(handlerMock), "Handler should be set");
    }

    function testWithdrawToken() public {
        uint256 amount = 100 ether;
        address to = address(0x1);
        // Setup: Send reward tokens to RewardTracker contract
        rewardToken.transfer(address(rewardTracker), amount);
        vm.prank(gov);
        rewardTracker.withdrawToken(address(rewardToken), to, amount);
        // Check balance of `to` after withdrawal
        assertEq(rewardToken.balanceOf(to), amount);
    }

    function testRewardToken() public view {
        address expectedRewardTokenAddress = address(rewardToken);
        address rewardTokenAddress = rewardTracker.rewardToken();
        assertEq(rewardTokenAddress, expectedRewardTokenAddress, "Reward token address does not match expected value");
    }

    function testApproveAndAllowance() public {
        vm.prank(accountB);
        rewardTracker.approve(accountA, 1000);

        assertEq(rewardTracker.allowance(accountB, accountA), 1000);
    }

    function testTokensPerInternal() public {
        rewardDistributor.updateLastDistributionTime();
        rewardDistributor.setTokensPerInterval(100);
        assertEq(rewardTracker.tokensPerInterval(), 100);
    }

    function testUpdateRewards() public {
        uint256 cumulativeRewardsBeforeUpdate = rewardTracker.cumulativeRewardPerToken();
        //Set Cumulative rewards per token to test update rewards when address is null
        rewardToken.transfer(address(rewardDistributor), 10000000);
        rewardDistributor.updateLastDistributionTime();
        rewardDistributor.setTokensPerInterval(100);

        //Stake some tokens to create total supply
        vm.prank(accountA);
        depositToken.approve(address(rewardTracker), 100);
        vm.prank(accountA);
        rewardTracker.stake(address(depositToken), 100);

        vm.warp(block.timestamp + 1 hours);
        rewardTracker.updateRewards();
        uint256 cumulativeRewardsAfterUpdate = rewardTracker.cumulativeRewardPerToken();
        //ToDo - optimise this test to calculate the exact amount of cumulative rewards added
        assertEq(cumulativeRewardsAfterUpdate > cumulativeRewardsBeforeUpdate, true);
    }

    function testStakeUnstakeAndBalanceOf() public {
        uint256 totalSupplyBeforeStake = rewardTracker.totalSupply();
        uint256 accountBalanceBeforeStake = rewardTracker.balances(address(accountB));

        rewardDistributor.updateLastDistributionTime();
        rewardDistributor.setTokensPerInterval(100);
        vm.prank(accountB);
        depositToken.approve(address(rewardTracker), 100);
        vm.prank(accountB);
        rewardTracker.stake(address(depositToken), 100);
        
        uint256 totalSupplyAfterStake = rewardTracker.totalSupply();
        uint256 accountBalanceAfterStake = rewardTracker.balances(address(accountB));

        assertEq(totalSupplyAfterStake - totalSupplyBeforeStake, 100);
        assertEq(accountBalanceAfterStake - accountBalanceBeforeStake, 100);

        uint256 accountBalance = rewardTracker.balanceOf(accountB);
        assertEq(accountBalance, 100);

        vm.prank(accountB);
        rewardTracker.unstake(address(depositToken), 100);
        
        uint256 totalSupplyAfterUnStake = rewardTracker.totalSupply();
        uint256 accountBalanceAfterUnStake = rewardTracker.balances(address(accountB));
        assertEq(totalSupplyBeforeStake, totalSupplyAfterUnStake);
        assertEq(accountBalanceBeforeStake, accountBalanceAfterUnStake);
    }

    function testStakeAndUnstakeForAccount() public {
        vm.prank(gov);
        address handlerMock = address(150);
        rewardTracker.setHandler(handlerMock, true);

        uint256 totalSupplyBeforeStake = rewardTracker.totalSupply();
        uint256 accountBalanceBeforeStake = rewardTracker.balances(address(accountB));

        rewardDistributor.updateLastDistributionTime();
        rewardDistributor.setTokensPerInterval(100);
        vm.prank(accountB);
        depositToken.approve(address(rewardTracker), 100);
        vm.prank(address(150));
        rewardTracker.stakeForAccount(accountB, accountB, address(depositToken), 100);
        
        uint256 totalSupplyAfterStake = rewardTracker.totalSupply();
        uint256 accountBalanceAfterStake = rewardTracker.balances(address(accountB));

        assertEq(totalSupplyAfterStake - totalSupplyBeforeStake, 100);
        assertEq(accountBalanceAfterStake - accountBalanceBeforeStake, 100);

        uint256 accountBalance = rewardTracker.balanceOf(accountB);
        assertEq(accountBalance, 100);

        vm.prank(address(150));
        rewardTracker.unstakeForAccount(accountB, address(depositToken), 100, accountB);
        
        uint256 totalSupplyAfterUnStake = rewardTracker.totalSupply();
        uint256 accountBalanceAfterUnStake = rewardTracker.balances(address(accountB));
        assertEq(totalSupplyBeforeStake, totalSupplyAfterUnStake);
        assertEq(accountBalanceBeforeStake, accountBalanceAfterUnStake);
    }

    //ToDo - need to write tests for the following functions -
    //  updateRewards(),
    //  transfer(), transferFrom(), claimRewards(), claimRewardsForAccount(), claimableRewards(), 
}