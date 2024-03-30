// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/RewardDistributor.sol"; // Update the path according to your project structure

/**
    @ToDo - need to deploy dummy rewardTracker contract for the following tests to pass
            testPendingRewardsAfterBlocksHavePassed()
            testPendingRewardsWhenNoTimeHasPassed()
            testSetTokensPerInterval()
 */
import "forge-std/console.sol";

contract RewardDistributorTest is Test {
    RewardDistributor rewardDistributor;
    address rewardToken = address(1); // Dummy address for the reward token
    address rewardTracker = address(2); // Dummy address for the reward tracker

    function setUp() public {
        rewardDistributor = new RewardDistributor(rewardToken, rewardTracker);
    }

    function testInitialAdminIsCorrect() view public {
        assertEq(rewardDistributor.admin(), address(this));
    }

    function testUpdateLastDistributionTime() public {
        rewardDistributor.updateLastDistributionTime();
        assertEq(rewardDistributor.lastDistributionTime(), block.timestamp);
    }

    function testSetTokensPerInterval() public {
        // First, update the last distribution time to enable setting tokens per interval
        rewardDistributor.updateLastDistributionTime();
        uint256 amount = 100;
        rewardDistributor.setTokensPerInterval(amount);
        assertEq(rewardDistributor.tokensPerInterval(), amount);
    }

    function testPendingRewardsAfterBlocksHavePassed() public {
        rewardDistributor.updateLastDistributionTime();
        uint256 tokensPerInterval = 10;
        rewardDistributor.setTokensPerInterval(tokensPerInterval);
        
        // Simulate time passing
        uint256 timeDiff = 10; // 10 seconds
        vm.warp(block.timestamp + timeDiff);

        uint256 expectedPendingRewards = tokensPerInterval * timeDiff;
        assertEq(rewardDistributor.pendingRewards(), expectedPendingRewards);
    }

    function testPendingRewardsWhenNoTimeHasPassed() public {
        rewardDistributor.updateLastDistributionTime();
        uint256 tokensPerInterval = 10;
        rewardDistributor.setTokensPerInterval(tokensPerInterval);
        
        // Do not advance time here to simulate the condition where
        // block.timestamp == lastDistributionTime

        // Expected pending rewards should be 0 since no time has passed
        uint256 expectedPendingRewards = 0;
        assertEq(rewardDistributor.pendingRewards(), expectedPendingRewards, "Pending rewards should be 0 when no time has passed since the last distribution");
    }
}
