// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/RewardTracker.sol";
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

contract RewardTrackerTest is Test {
    RewardTracker rewardTracker;
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
        rewardTracker = new RewardTracker('LogX Token', 'LOGX');
        //Vesting and deposit token are the same ($LOGX token)
        rewardTracker.initialize(address(depositToken), address(depositToken));

        //Transfer 100 depositTokens to accountA, accountB and rewardTracker (*10^18)
        depositToken.transfer(accountB, 100000000000000000000);
        depositToken.transfer(accountA, 100000000000000000000);
        depositToken.transfer(address(rewardTracker), 100000000000000000000);
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

    function testSetHandlerFailNonGov() public {
        address nonGov = address(999); // Example address that is not the governor
        address handlerMock = address(150);

        vm.prank(nonGov); // Prank with a non-gov address
        vm.expectRevert("Governable: forbidden"); // Assuming your contract reverts with this message for unauthorized access

        rewardTracker.setHandler(handlerMock, true);

        assertFalse(rewardTracker.isHandler(handlerMock), "Handler should not be set by non-gov address");
    }

    function testWithdrawToken() public {
        uint256 amount = 100 ether;
        address to = address(0x1);
        // Setup: Send reward tokens to RewardTracker contract
        erc20.transfer(address(rewardTracker), amount);
        vm.prank(gov);
        rewardTracker.withdrawToken(address(erc20), to, amount);
        // Check balance of `to` after withdrawal
        assertEq(erc20.balanceOf(to), amount);
    }

    function testApproveAndAllowance() public {
        vm.prank(accountB);
        rewardTracker.approve(accountA, 1000);

        assertEq(rewardTracker.allowance(accountB, accountA), 1000);
    }

    function testSetAPRForDurationInDaysSuccess() public {
        uint256 duration = 30;
        uint256 apy = 20000;

        vm.startPrank(gov);
        rewardTracker.setAPRForDurationInDays(duration, apy);
        vm.stopPrank();

        uint256 setApy = rewardTracker.apyForDuration(duration);
        assertEq(setApy, apy, "APY should be correctly set for the duration");
    }

    function testSetAPRForDurationInDaysFailNonGov() public {
        uint256 duration = 30;
        uint256 apy = 20000;
        address nonGov = address(2); // An address not authorized as governor

        vm.startPrank(nonGov);
        vm.expectRevert("Governable: forbidden");
        rewardTracker.setAPRForDurationInDays(duration, apy);
        vm.stopPrank();
    }

    function testStake() public {
        //Using Account 'A' to stake
        uint256 stakedAmountBefore = rewardTracker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyBefore = rewardTracker.totalDepositSupply();
        uint256 balanceBefore = rewardTracker.balanceOf(address(accountA));
        uint256 totalSupplyBefore = rewardTracker.totalSupply();


        vm.startPrank(accountA);
        depositToken.approve(address(rewardTracker), 50000000000000000000);
        rewardTracker.stake(address(depositToken), 50000000000000000000, 10);
        vm.stopPrank();

        uint256 stakedAmountAfter = rewardTracker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyAfter = rewardTracker.totalDepositSupply();
        uint256 balanceAfter = rewardTracker.balanceOf(address(accountA));
        uint256 totalSupplyAfter = rewardTracker.totalSupply();

        assertEq(stakedAmountAfter - stakedAmountBefore, 50000000000000000000);
        assertEq(totalDepositSupplyAfter - totalDepositSupplyBefore, 50000000000000000000);
        assertEq(balanceAfter - balanceBefore, 50000000000000000000);
        assertEq(totalSupplyAfter - totalSupplyBefore, 50000000000000000000);

        bytes32[] memory stakeIds = rewardTracker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];
        uint256 amountStaked = rewardTracker.getAmountForStakeId(stakeId);
        address accountStaked = rewardTracker.getAccountForStakeId(stakeId);
        assertEq(amountStaked, 50000000000000000000);
        assertEq(accountStaked, address(accountA));
    }

    function testUnstake() public {
        //Using Account 'A' to Stake
        vm.startPrank(accountA);
        depositToken.approve(address(rewardTracker), 50000000000000000000);
        rewardTracker.stake(address(depositToken), 50000000000000000000, 7);
        vm.stopPrank();

        bytes32[] memory stakeIds = rewardTracker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];
        //Testing unstake logic 
        uint256 stakedAmountBefore = rewardTracker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyBefore = rewardTracker.totalDepositSupply();
        uint256 balanceBefore = rewardTracker.balanceOf(address(accountA));
        uint256 totalSupplyBefore = rewardTracker.totalSupply();

        //Simulate passage of time so staking duration ends
        vm.warp(8 days);
        vm.startPrank(accountA);
        rewardTracker.unstake(address(depositToken), stakeId);
        vm.stopPrank();

        uint256 stakedAmountAfter = rewardTracker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyAfter = rewardTracker.totalDepositSupply();
        uint256 balanceAfter = rewardTracker.balanceOf(address(accountA));
        uint256 totalSupplyAfter = rewardTracker.totalSupply();

        assertEq(stakedAmountBefore - stakedAmountAfter, 50000000000000000000);
        assertEq(totalDepositSupplyBefore - totalDepositSupplyAfter, 50000000000000000000);
        assertEq(balanceBefore - balanceAfter, 50000000000000000000);
        assertEq(totalSupplyBefore - totalSupplyAfter, 50000000000000000000);
    }

    function testStakeForAccount() public {
        vm.prank(gov);
        address handlerMock = address(150);
        rewardTracker.setHandler(handlerMock, true);

        //Using Account 'B' to stake for Account 'A'
        uint256 stakedAmountBefore = rewardTracker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyBefore = rewardTracker.totalDepositSupply();
        uint256 balanceBefore = rewardTracker.balanceOf(address(accountA));
        uint256 totalSupplyBefore = rewardTracker.totalSupply();


        vm.prank(accountA);
        depositToken.approve(address(rewardTracker), 50000000000000000000);
        vm.prank(address(150));
        rewardTracker.stakeForAccount(accountA, accountA, address(depositToken), 50000000000000000000, 10);

        uint256 stakedAmountAfter = rewardTracker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyAfter = rewardTracker.totalDepositSupply();
        uint256 balanceAfter = rewardTracker.balanceOf(address(accountA));
        uint256 totalSupplyAfter = rewardTracker.totalSupply();

        assertEq(stakedAmountAfter - stakedAmountBefore, 50000000000000000000);
        assertEq(totalDepositSupplyAfter - totalDepositSupplyBefore, 50000000000000000000);
        assertEq(balanceAfter - balanceBefore, 50000000000000000000);
        assertEq(totalSupplyAfter - totalSupplyBefore, 50000000000000000000);

        bytes32[] memory stakeIds = rewardTracker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];
        uint256 amountStaked = rewardTracker.getAmountForStakeId(stakeId);
        address accountStaked = rewardTracker.getAccountForStakeId(stakeId);
        assertEq(amountStaked, 50000000000000000000);
        assertEq(accountStaked, address(accountA));
    }

    function testUnstakeForAccount() public {
        vm.prank(gov);
        address handlerMock = address(150);
        rewardTracker.setHandler(handlerMock, true);

        //Using Account 'A' to Stake
        vm.startPrank(accountA);
        depositToken.approve(address(rewardTracker), 50000000000000000000);
        rewardTracker.stake(address(depositToken), 50000000000000000000, 7);
        vm.stopPrank();

        bytes32[] memory stakeIds = rewardTracker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];
        //Testing unstake logic 
        uint256 stakedAmountBefore = rewardTracker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyBefore = rewardTracker.totalDepositSupply();
        uint256 balanceBefore = rewardTracker.balanceOf(address(accountA));
        uint256 totalSupplyBefore = rewardTracker.totalSupply();

        //Simulate passage of time so staking duration ends
        vm.warp(8 days);
        vm.prank(address(150));
        rewardTracker.unstakeForAccount(accountA, address(depositToken), accountA, stakeId);


        uint256 stakedAmountAfter = rewardTracker.stakedAmounts(address(accountA));
        uint256 totalDepositSupplyAfter = rewardTracker.totalDepositSupply();
        uint256 balanceAfter = rewardTracker.balanceOf(address(accountA));
        uint256 totalSupplyAfter = rewardTracker.totalSupply();

        assertEq(stakedAmountBefore - stakedAmountAfter, 50000000000000000000);
        assertEq(totalDepositSupplyBefore - totalDepositSupplyAfter, 50000000000000000000);
        assertEq(balanceBefore - balanceAfter, 50000000000000000000);
        assertEq(totalSupplyBefore - totalSupplyAfter, 50000000000000000000);
    }

    function testUnstakeBeforeDurationEnd() public {
        //Using Account 'A' to Stake
        vm.startPrank(accountA);
        depositToken.approve(address(rewardTracker), 50000000000000000000);
        rewardTracker.stake(address(depositToken), 50000000000000000000, 7);
        vm.stopPrank();

        bytes32[] memory stakeIds = rewardTracker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];

        vm.startPrank(accountA);
        vm.expectRevert("RewardTracker: staking duration active");
        rewardTracker.unstake(address(depositToken), stakeId);
        vm.stopPrank();
    }

    function testUnstakingWithWrongAccount() public {
        //Using Account 'A' to Stake
        vm.startPrank(accountA);
        depositToken.approve(address(rewardTracker), 50000000000000000000);
        rewardTracker.stake(address(depositToken), 50000000000000000000, 7);
        vm.stopPrank();

        bytes32[] memory stakeIds = rewardTracker.getUserIds(accountA);
        bytes32 stakeId = stakeIds[0];

        vm.startPrank(accountB);
        vm.expectRevert("RewardTracker: invalid _stakeId for _account");
        rewardTracker.unstake(address(depositToken), stakeId);
        vm.stopPrank();
    }

    function testTransfer() public {
        //We need to stake some amount to make sure the wallet has stLOGX balance for transfer
        //Using Account 'A' to Stake
        vm.startPrank(accountA);
        depositToken.approve(address(rewardTracker), 50000000000000000000);
        rewardTracker.stake(address(depositToken), 50000000000000000000, 7);
        bool success = rewardTracker.transfer(accountB, 25000000000000000000);
        vm.stopPrank();

        assertTrue(success, "Transfer failed");
        assertEq(rewardTracker.balanceOf(accountA), 25000000000000000000, "Incorrect balance for accountA after transfer");
        assertEq(rewardTracker.balanceOf(accountB), 25000000000000000000, "Incorrect balance for accountB after transfer");
    }

    function testTransferFrom() public {
        //We need to stake some amount to make sure the wallet has stLOGX balance for transfer
        //Using Account 'A' to Stake
        vm.startPrank(accountA);
        depositToken.approve(address(rewardTracker), 50000000000000000000);
        rewardTracker.stake(address(depositToken), 50000000000000000000, 7);
        rewardTracker.approve(address(this), 25000000000000000000);
        vm.stopPrank();

        bool success = rewardTracker.transferFrom(accountA, accountB, 25000000000000000000);

        assertTrue(success, "TransferFrom failed");
        assertEq(rewardTracker.balanceOf(accountA), 25000000000000000000, "Incorrect balance for accountA after transferFrom");
        assertEq(rewardTracker.balanceOf(accountB), 25000000000000000000, "Incorrect balance for accountB after transferFrom");
    }
        
    //ToDo - claimVestedTokens(), claimVestedTokensForAccount()
}