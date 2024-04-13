// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/RewardDistributor.sol";
import "../src/LogxStaker.sol";

contract MockERC20 {
    string public name = "Mock ERC20 Token";
    string public symbol = "MCK";
    uint256 public totalSupply = 1e24;
    mapping(address => uint256) public balanceOf;

    constructor() {
        balanceOf[msg.sender] = totalSupply;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract RewardDistributorTest is Test {
    RewardDistributor rewardDistributor;
    LogxStaker logxStaker;
    MockERC20 rewardToken;
    MockERC20 depositToken;

    function setUp() public {
        rewardToken = new MockERC20();
        depositToken = new MockERC20();
        logxStaker = new LogxStaker('LogX Token', 'LOGX');
        rewardDistributor = new RewardDistributor(address(rewardToken), address(logxStaker));
        logxStaker.initialize(address(depositToken), address(depositToken), address(rewardDistributor));
        rewardToken.transfer(address(rewardDistributor), 500 ether); // Simulate funding the contract
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

    function testDistribute() public {
        rewardDistributor.updateLastDistributionTime();
        rewardDistributor.setTokensPerInterval(10 ether);
        // Simulate time passing
        vm.warp(block.timestamp + 1 hours);

        // Only logxStaker can call distribute
        vm.prank(address(logxStaker));
        uint256 amountDistributed = rewardDistributor.distribute();

        assertEq(amountDistributed, 500 ether, "Distributed amount does not match expected value");
    }
}