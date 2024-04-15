// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/LogxStaker.sol";
import "../src/RewardDistributor.sol";
import "../libraries/open-zeppelin/ERC20.sol";

contract ERC20Token is ERC20 {
    constructor(uint256 initialSupply) ERC20("ERC20 Token", "ERC") {
        _mint(msg.sender, initialSupply);
    }
}

contract DepositToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Deposit Token", "DEP") {
        _mint(msg.sender, initialSupply);
    }
}

contract logxStakerTest is Test {
    RewardDistributor rewardDistributor;
    LogxStaker logxStaker;
    DepositToken depositToken;
    ERC20Token erc20;
    //Testing accounts
    address accountA;
    address accountB;
    //Address which deployed the contract will be gov
    address gov = address(this);

    function setUp() public {
        accountA = address(1001);
        accountB = address(1002);
        erc20 = new ERC20Token(1e24);
        depositToken = new DepositToken(1e24);
        logxStaker = new LogxStaker('LogX Token', 'LOGX');
        rewardDistributor = new RewardDistributor(address(erc20), address(logxStaker));
        //Vesting and deposit token are the same ($LOGX token)
        logxStaker.initialize(address(depositToken), address(depositToken), address(rewardDistributor));

        //Transfer 100 depositTokens to accountA, accountB and logxStaker (*10^18)
        depositToken.transfer(accountB, 150000000000000000000);
        depositToken.transfer(accountA, 100000000000000000000);
        depositToken.transfer(address(logxStaker), 100000000000000000000);
        erc20.transfer(address(rewardDistributor), 1000000000);
    }

    function testSetInPrivateTransferMode() public {
        vm.prank(gov);
        logxStaker.setInPrivateTransferMode(true);
        assertTrue(logxStaker.inPrivateTransferMode());
    }

    function testSetInPrivateStakingMode() public {
        vm.prank(gov);
        logxStaker.setInPrivateStakingMode(true);
        assertTrue(logxStaker.inPrivateStakingMode());
    }

    function testSetInPrivateClaimingMode() public {
        vm.prank(gov);
        logxStaker.setInPrivateClaimingMode(true);
        assertTrue(logxStaker.inPrivateClaimingMode());
    }

    function testSetHandler() public {
        vm.prank(gov);
        address handlerMock = address(150);
        logxStaker.setHandler(handlerMock, true);
        assertTrue(logxStaker.isHandler(handlerMock), "Handler should be set");
    }

    function testSetHandlerFailNonGov() public {
        address nonGov = address(999); // Example address that is not the governor
        address handlerMock = address(150);

        vm.prank(nonGov); // Prank with a non-gov address
        vm.expectRevert("Governable: forbidden"); // Assuming your contract reverts with this message for unauthorized access

        logxStaker.setHandler(handlerMock, true);

        assertFalse(logxStaker.isHandler(handlerMock), "Handler should not be set by non-gov address");
    }

    function testWithdrawToken() public {
        uint256 amount = 100 ether;
        address to = address(0x1);
        // Setup: Send reward tokens to logxStaker contract
        erc20.transfer(address(logxStaker), amount);
        vm.prank(gov);
        logxStaker.withdrawToken(address(erc20), to, amount);
        // Check balance of `to` after withdrawal
        assertEq(erc20.balanceOf(to), amount);
    }

    function testApproveAndAllowance() public {
        vm.prank(accountB);
        logxStaker.approve(accountA, 1000);

        assertEq(logxStaker.allowance(accountB, accountA), 1000);
    }

    function testSetAPRForDurationInDaysSuccess() public {
        uint256 duration = 30;
        uint256 apy = 20000;

        vm.startPrank(gov);
        logxStaker.setAPRForDurationInDays(duration, apy);
        vm.stopPrank();

        uint256 setApy = logxStaker.apyForDuration(duration);
        assertEq(setApy, apy, "APY should be correctly set for the duration");
    }

    function testSetAPRForDurationInDaysFailNonGov() public {
        uint256 duration = 30;
        uint256 apy = 20000;
        address nonGov = address(2); // An address not authorized as governor

        vm.startPrank(nonGov);
        vm.expectRevert("Governable: forbidden");
        logxStaker.setAPRForDurationInDays(duration, apy);
        vm.stopPrank();
    }

    function testStake() public {
        //Using Account 'A' to stake
        uint256 stakedAmountBefore = logxStaker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyBefore = logxStaker.totalDepositSupply();
        uint256 balanceBefore = logxStaker.balanceOf(address(accountA));
        uint256 totalSupplyBefore = logxStaker.totalSupply();


        vm.startPrank(accountA);
        depositToken.approve(address(logxStaker), 50000000000000000000);
        logxStaker.stake(address(depositToken), 50000000000000000000, 10);
        vm.stopPrank();

        uint256 stakedAmountAfter = logxStaker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyAfter = logxStaker.totalDepositSupply();
        uint256 balanceAfter = logxStaker.balanceOf(address(accountA));
        uint256 totalSupplyAfter = logxStaker.totalSupply();

        assertEq(stakedAmountAfter - stakedAmountBefore, 50000000000000000000);
        assertEq(totalDepositSupplyAfter - totalDepositSupplyBefore, 50000000000000000000);
        assertEq(balanceAfter - balanceBefore, 50000000000000000000);
        assertEq(totalSupplyAfter - totalSupplyBefore, 50000000000000000000);

        bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];
        uint256 amountStaked = logxStaker.getAmountForStakeId(stakeId);
        address accountStaked = logxStaker.getAccountForStakeId(stakeId);
        assertEq(amountStaked, 50000000000000000000);
        assertEq(accountStaked, address(accountA));
    }

    function testUnstake() public {
        //Using Account 'A' to Stake
        vm.startPrank(accountA);
        depositToken.approve(address(logxStaker), 50000000000000000000);
        logxStaker.stake(address(depositToken), 50000000000000000000, 7);
        vm.stopPrank();

        bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];
        //Testing unstake logic 
        uint256 stakedAmountBefore = logxStaker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyBefore = logxStaker.totalDepositSupply();
        uint256 balanceBefore = logxStaker.balanceOf(address(accountA));
        uint256 totalSupplyBefore = logxStaker.totalSupply();

        //Simulate passage of time so staking duration ends
        vm.warp(8 days);
        vm.startPrank(accountA);
        logxStaker.unstake(address(depositToken), stakeId);
        vm.stopPrank();

        uint256 stakedAmountAfter = logxStaker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyAfter = logxStaker.totalDepositSupply();
        uint256 balanceAfter = logxStaker.balanceOf(address(accountA));
        uint256 totalSupplyAfter = logxStaker.totalSupply();

        assertEq(stakedAmountBefore - stakedAmountAfter, 50000000000000000000);
        assertEq(totalDepositSupplyBefore - totalDepositSupplyAfter, 50000000000000000000);
        assertEq(balanceBefore - balanceAfter, 50000000000000000000);
        assertEq(totalSupplyBefore - totalSupplyAfter, 50000000000000000000);
    }

    function testStakeForAccount() public {
        vm.prank(gov);
        address handlerMock = address(150);
        logxStaker.setHandler(handlerMock, true);

        //Using Account 'B' to stake for Account 'A'
        uint256 stakedAmountBefore = logxStaker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyBefore = logxStaker.totalDepositSupply();
        uint256 balanceBefore = logxStaker.balanceOf(address(accountA));
        uint256 totalSupplyBefore = logxStaker.totalSupply();


        vm.prank(accountA);
        depositToken.approve(address(logxStaker), 50000000000000000000);
        vm.prank(address(150));
        logxStaker.stakeForAccount(accountA, accountA, address(depositToken), 50000000000000000000, 10);

        uint256 stakedAmountAfter = logxStaker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyAfter = logxStaker.totalDepositSupply();
        uint256 balanceAfter = logxStaker.balanceOf(address(accountA));
        uint256 totalSupplyAfter = logxStaker.totalSupply();

        assertEq(stakedAmountAfter - stakedAmountBefore, 50000000000000000000);
        assertEq(totalDepositSupplyAfter - totalDepositSupplyBefore, 50000000000000000000);
        assertEq(balanceAfter - balanceBefore, 50000000000000000000);
        assertEq(totalSupplyAfter - totalSupplyBefore, 50000000000000000000);

        bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];
        uint256 amountStaked = logxStaker.getAmountForStakeId(stakeId);
        address accountStaked = logxStaker.getAccountForStakeId(stakeId);
        assertEq(amountStaked, 50000000000000000000);
        assertEq(accountStaked, address(accountA));
    }

    function testUnstakeForAccount() public {
        vm.prank(gov);
        address handlerMock = address(150);
        logxStaker.setHandler(handlerMock, true);

        //Using Account 'A' to Stake
        vm.startPrank(accountA);
        depositToken.approve(address(logxStaker), 50000000000000000000);
        logxStaker.stake(address(depositToken), 50000000000000000000, 7);
        vm.stopPrank();

        bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];
        //Testing unstake logic 
        uint256 stakedAmountBefore = logxStaker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyBefore = logxStaker.totalDepositSupply();
        uint256 balanceBefore = logxStaker.balanceOf(address(accountA));
        uint256 totalSupplyBefore = logxStaker.totalSupply();

        //Simulate passage of time so staking duration ends
        vm.warp(8 days);
        vm.prank(address(150));
        logxStaker.unstakeForAccount(accountA, address(depositToken), accountA, stakeId);


        uint256 stakedAmountAfter = logxStaker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyAfter = logxStaker.totalDepositSupply();
        uint256 balanceAfter = logxStaker.balanceOf(address(accountA));
        uint256 totalSupplyAfter = logxStaker.totalSupply();

        assertEq(stakedAmountBefore - stakedAmountAfter, 50000000000000000000);
        assertEq(totalDepositSupplyBefore - totalDepositSupplyAfter, 50000000000000000000);
        assertEq(balanceBefore - balanceAfter, 50000000000000000000);
        assertEq(totalSupplyBefore - totalSupplyAfter, 50000000000000000000);
    }

    function testUnstakeBeforeDurationEnd() public {
        //Using Account 'A' to Stake
        vm.startPrank(accountA);
        depositToken.approve(address(logxStaker), 50000000000000000000);
        logxStaker.stake(address(depositToken), 50000000000000000000, 7);
        vm.stopPrank();

        bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];

        vm.startPrank(accountA);
        vm.expectRevert("LogxStaker: staking duration active");
        logxStaker.unstake(address(depositToken), stakeId);
        vm.stopPrank();
    }

    function testUnstakingWithWrongAccount() public {
        //Using Account 'A' to Stake
        vm.startPrank(accountA);
        depositToken.approve(address(logxStaker), 50000000000000000000);
        logxStaker.stake(address(depositToken), 50000000000000000000, 7);
        vm.stopPrank();

        bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];

        vm.startPrank(accountB);
        vm.expectRevert("LogxStaker: invalid _stakeId for _account");
        logxStaker.unstake(address(depositToken), stakeId);
        vm.stopPrank();
    }

    function testTransfer() public {
        //We need to stake some amount to make sure the wallet has stLOGX balance for transfer
        //Using Account 'A' to Stake
        vm.startPrank(accountA);
        depositToken.approve(address(logxStaker), 50000000000000000000);
        logxStaker.stake(address(depositToken), 50000000000000000000, 7);
        bool success = logxStaker.transfer(accountB, 25000000000000000000);
        vm.stopPrank();

        assertTrue(success, "Transfer failed");
        assertEq(logxStaker.balanceOf(accountA), 25000000000000000000, "Incorrect balance for accountA after transfer");
        assertEq(logxStaker.balanceOf(accountB), 25000000000000000000, "Incorrect balance for accountB after transfer");
    }

    function testTransferFrom() public {
        //We need to stake some amount to make sure the wallet has stLOGX balance for transfer
        //Using Account 'A' to Stake
        vm.startPrank(accountA);
        depositToken.approve(address(logxStaker), 50000000000000000000);
        logxStaker.stake(address(depositToken), 50000000000000000000, 7);
        logxStaker.approve(address(this), 25000000000000000000);
        vm.stopPrank();

        bool success = logxStaker.transferFrom(accountA, accountB, 25000000000000000000);

        assertTrue(success, "TransferFrom failed");
        assertEq(logxStaker.balanceOf(accountA), 25000000000000000000, "Incorrect balance for accountA after transferFrom");
        assertEq(logxStaker.balanceOf(accountB), 25000000000000000000, "Incorrect balance for accountB after transferFrom");
    }

    function testClaimVestedTokens() public {
        //To test for the vesting math, we will deposit
        // 91.25 tokens for 30 days at 20% APR, earning 1.5 tokens at the end of vesting period
        //Using Account 'A' to Stake
        vm.startPrank(accountA);
        depositToken.approve(address(logxStaker), 91250000000000000000);
        logxStaker.stake(address(depositToken), 91250000000000000000, 30);
        vm.stopPrank();

        bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];
        
        //Simulate passage of time so staking duration ends
        vm.warp(31 days);
        vm.startPrank(accountA);
        logxStaker.unstake(address(depositToken), stakeId);
        uint256 amount = logxStaker.claimVestedTokens();
        vm.stopPrank();

        assertEq(amount, 1500000000000000000, "Incorrect vested tokens");
    }

    function testClaimVestedTokensForAccount() public {
        vm.prank(gov);
        address handlerMock = address(150);
        logxStaker.setHandler(handlerMock, true);

        //To test for the vesting math, we will deposit
        // 91.25 tokens for 30 days at 20% APR, earning 1.5 tokens at the end of vesting period
        //Using Account 'A' to Stake
        vm.startPrank(accountA);
        depositToken.approve(address(logxStaker), 91250000000000000000);
        logxStaker.stake(address(depositToken), 91250000000000000000, 30);
        vm.stopPrank();

        bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];
        
        //Simulate passage of time so staking duration ends
        vm.warp(31 days);
        vm.startPrank(accountA);
        logxStaker.unstake(address(depositToken), stakeId);
        vm.stopPrank();

        vm.prank(address(150));
        uint256 amount = logxStaker.claimVestedTokensForAccount(address(accountA), address(accountA));

        assertEq(amount, 1500000000000000000, "Incorrect vested tokens");
    }

    //ToDo - add unit test cases for claimFeeRewardsForAccount()
    function testClaimFeeRewards() public {
        //Initialise rewards distributor
        rewardDistributor.updateLastDistributionTime();
        rewardDistributor.setTokensPerInterval(1);

        //Stake from 2 accounts
        vm.startPrank(accountA);
        depositToken.approve(address(logxStaker), 50000000000000000000);
        logxStaker.stake(address(depositToken), 50000000000000000000, 10);
        vm.stopPrank();

        vm.startPrank(accountB);
        depositToken.approve(address(logxStaker), 150000000000000000000);
        logxStaker.stake(address(depositToken), 150000000000000000000, 30);
        vm.stopPrank();

        vm.warp(1 days);

        uint256 claimableRewardsA = logxStaker.claimableFeeRewards(address(accountA));
        uint256 claimableRewardsB = logxStaker.claimableFeeRewards(address(accountB));
        vm.prank(accountA);
        uint256 rewardsA = logxStaker.claimFeeRewards(address(accountA));
        vm.prank(accountB);
        uint256 rewardsB = logxStaker.claimFeeRewards(address(accountB));

        //Account A has deposited 50 tokens and Account B has deposited 150 tokens
        //Account B should get 3X fee rewards as Account A
        //For duration of 1 day, total rewards distributed will be 60 * 60 * 24 (minus 1 for some reason - could have to do with the way the test case was written)
        //  with 1 as "token per interval"
        //Among these tokens, share of Account b - (3/4th) 64,799
        //  and share of Account a - (1/4th) 21,599
        assertEq(rewardsB, 64799, "Incorrect rewards distributed for account B");
        assertEq(rewardsA, 21599, "Incorrect rewards distributed for account A");
        assertEq(claimableRewardsB, 64799, "Incorrect claimable rewards for account B");
        assertEq(claimableRewardsA, 21599, "Incorrect claimable rewards for account A");
    }

    function testClaimFeeRewardsForAccount() public {
        vm.prank(gov);
        address handlerMock = address(150);
        logxStaker.setHandler(handlerMock, true);

        //Initialise rewards distributor
        rewardDistributor.updateLastDistributionTime();
        rewardDistributor.setTokensPerInterval(1);

        //Stake from account A
        vm.startPrank(accountA);
        depositToken.approve(address(logxStaker), 50000000000000000000);
        logxStaker.stake(address(depositToken), 50000000000000000000, 10);
        vm.stopPrank();

        vm.warp(1 days);

        uint256 claimableRewardsA = logxStaker.claimableFeeRewards(address(accountA));
        assertEq(claimableRewardsA, 86399, "Incorrect claimable rewards for account A");

        vm.prank(address(150));
        uint256 rewardsA = logxStaker.claimFeeRewardsForAccount(address(accountA), address(accountA));

        assertEq(rewardsA, 86399, "Incorrect rewards distributed for account A");
    }

    function testRestake() public {
        //Normal staking
        vm.startPrank(accountA);
        depositToken.approve(address(logxStaker), 50000000000000000000);
        logxStaker.stake(address(depositToken), 50000000000000000000, 10);
        vm.stopPrank();

        bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];
        
        vm.warp(11 days);

        uint256 stakedAmountBefore = logxStaker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyBefore = logxStaker.totalDepositSupply();
        uint256 balanceBefore = logxStaker.balanceOf(address(accountA));
        uint256 totalSupplyBefore = logxStaker.totalSupply();

        vm.startPrank(accountA);
        logxStaker.restake(address(depositToken), stakeId, 15);
        vm.stopPrank();

        uint256 stakedAmountAfter = logxStaker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyAfter = logxStaker.totalDepositSupply();
        uint256 balanceAfter = logxStaker.balanceOf(address(accountA));
        uint256 totalSupplyAfter = logxStaker.totalSupply();

        assertEq(stakedAmountAfter, stakedAmountBefore, "Incorrect staked amounts");
        assertEq(totalDepositSupplyAfter, totalDepositSupplyBefore, "Incorrect total deposit supply");
        assertEq(balanceBefore, balanceAfter, "Incorrect balances");
        assertEq(totalSupplyBefore, totalSupplyAfter, "Incorrect total supply");

        LogxStaker.Stake memory stake = logxStaker.getStake(stakeId);
        assertEq(stake.duration, 15, "Incorrect stake duration");
    }

    function testRestakeForAccount() public {
        vm.prank(gov);
        address handlerMock = address(150);
        logxStaker.setHandler(handlerMock, true);

        //Normal staking
        vm.startPrank(accountA);
        depositToken.approve(address(logxStaker), 50000000000000000000);
        logxStaker.stake(address(depositToken), 50000000000000000000, 10);
        vm.stopPrank();

        bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];
        
        vm.warp(11 days);

        uint256 stakedAmountBefore = logxStaker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyBefore = logxStaker.totalDepositSupply();
        uint256 balanceBefore = logxStaker.balanceOf(address(accountA));
        uint256 totalSupplyBefore = logxStaker.totalSupply();

        vm.startPrank(address(150));
        logxStaker.restakeForAccount(address(accountA), address(depositToken), stakeId, 15);
        vm.stopPrank();

        uint256 stakedAmountAfter = logxStaker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyAfter = logxStaker.totalDepositSupply();
        uint256 balanceAfter = logxStaker.balanceOf(address(accountA));
        uint256 totalSupplyAfter = logxStaker.totalSupply();

        assertEq(stakedAmountAfter, stakedAmountBefore, "Incorrect staked amounts");
        assertEq(totalDepositSupplyAfter, totalDepositSupplyBefore, "Incorrect total deposit supply");
        assertEq(balanceBefore, balanceAfter, "Incorrect balances");
        assertEq(totalSupplyBefore, totalSupplyAfter, "Incorrect total supply");

        LogxStaker.Stake memory stake = logxStaker.getStake(stakeId);
        assertEq(stake.duration, 15, "Incorrect stake duration");
    }
}