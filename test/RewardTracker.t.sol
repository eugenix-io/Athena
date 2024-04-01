// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/RewardDistributor.sol";
import "../src/RewardTracker.sol";

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

contract RewardTrackerTest is Test {
    RewardDistributor rewardDistributor;
    RewardTracker rewardTracker;
    MockERC20 rewardToken;
    address gov = address(this);

    function setUp() public{
        rewardToken = new MockERC20();
        rewardTracker = new RewardTracker('LogX Token', 'LOGX');
        rewardDistributor = new RewardDistributor(address(rewardToken), address(rewardTracker));
        address[] memory depositTokens = new address[](1);
        depositTokens[0] = address(2);
        rewardTracker.initialize(depositTokens, address(rewardDistributor));
    }

    function testSetDepositToken() public {
        address depositToken = address(new MockERC20());
        
        vm.prank(gov);
        rewardTracker.setDepositToken(depositToken, true);
        assertTrue(rewardTracker.isDepositToken(depositToken));
    }

    function testFailSetDepositTokenByNonGov() public {
        address depositToken = address(new MockERC20());
        address nonGov = address(0xBEEF);
        
        vm.prank(nonGov);
        rewardTracker.setDepositToken(depositToken, true);
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
        address handlerMock = address(150); // Use a more realistic address in actual tests
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

    //ToDo - need to write tests for the following functions -
    //  balanceOf(), allowance(), tokensPerInterval(), updateRewards(), stake(), stakeForAccount(), unstake(),
    //  unstakeForAccount(), approve(), transfer(), transferFrom(), claim(), claimForAccount(), claimable(), 
}