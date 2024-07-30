// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import "forge-std/Test.sol";
// import "../src/LogxStaker.sol";
// import "../libraries/open-zeppelin/ERC20.sol";
// import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// contract ERC20Token is ERC20 {
//     constructor(uint256 initialSupply) ERC20("ERC20 Token", "ERC") {
//         _mint(msg.sender, initialSupply);
//     }
// }

// contract DepositToken is ERC20 {
//     constructor(uint256 initialSupply) ERC20("Deposit Token", "DEP") {
//         _mint(msg.sender, initialSupply);
//     }
// }

// contract logxStakerTest is Test {
//     LogxStaker logxStaker;
//     ERC20Token erc20;
//     //Testing accounts
//     address accountA;
//     address accountB;
//     //Address which deployed the contract will be gov
//     address gov = address(this);

//     function setUp() public {
//         accountA = address(1001);
//         accountB = address(1002);
//         erc20 = new ERC20Token(1e24);
//         LogxStaker logxStakerImpl = new LogxStaker();
//         //Vesting and deposit token are the same ($LOGX token)
//         TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logxStakerImpl),gov,""); 
//         logxStaker = LogxStaker(payable(address(proxy)));
//         logxStaker.initialize('LogX Token', 'LOGX');

//         //Transfer 100 depositTokens to accountA, accountB and logxStaker (*10^18)
//         vm.deal(accountB, 150 ether);
//         vm.deal(accountA, 365 ether);
//         vm.deal(address(logxStaker), 100 ether);
//     }

//     function testSetInPrivateTransferMode() public {
//         vm.prank(gov);
//         logxStaker.setInPrivateTransferMode(true);
//         assertTrue(logxStaker.inPrivateTransferMode());
//     }

//     function testSetInPrivateStakingMode() public {
//         vm.prank(gov);
//         logxStaker.setInPrivateStakingMode(true);
//         assertTrue(logxStaker.inPrivateStakingMode());
//     }

//     function testSetInPrivateClaimingMode() public {
//         vm.prank(gov);
//         logxStaker.setInPrivateClaimingMode(true);
//         assertTrue(logxStaker.inPrivateClaimingMode());
//     }

//     function testSetHandler() public {
//         vm.prank(gov);
//         address handlerMock = address(150);
//         logxStaker.setHandler(handlerMock, true);
//         assertTrue(logxStaker.isHandler(handlerMock), "Handler should be set");
//     }

//     function testSetHandlerFailNonGov() public {
//         address nonGov = address(999); // Example address that is not the governor
//         address handlerMock = address(150);

//         vm.prank(nonGov); // Prank with a non-gov address
//         vm.expectRevert(); // Assuming your contract reverts with this message for unauthorized access

//         logxStaker.setHandler(handlerMock, true);

//         assertFalse(logxStaker.isHandler(handlerMock), "Handler should not be set by non-gov address");
//     }

//     function testWithdrawToken() public {
//         uint256 amount = 100 ether;
//         address to = address(0x1);
//         // Setup: Send reward tokens to logxStaker contract
//         erc20.transfer(address(logxStaker), amount);
//         vm.prank(gov);
//         logxStaker.withdrawToken(address(erc20), to, amount);
//         // Check balance of `to` after withdrawal
//         assertEq(erc20.balanceOf(to), amount);
//     }

//     function testSetAPRForDurationInDaysSuccess() public {
//         uint256 duration = 30;
//         uint256 apy = 20000;

//         vm.startPrank(gov);
//         logxStaker.setAPRForDurationInDays(duration, apy);
//         vm.stopPrank();

//         uint256 setApy = logxStaker.apyForDuration(duration);
//         assertEq(setApy, apy, "APY should be correctly set for the duration");
//     }

//     function testSetAPRForDurationInDaysFailNonGov() public {
//         uint256 duration = 30;
//         uint256 apy = 20000;
//         address nonGov = address(2); // An address not authorized as governor

//         vm.startPrank(nonGov);
//         vm.expectRevert();
//         logxStaker.setAPRForDurationInDays(duration, apy);
//         vm.stopPrank();
//     }

//     function testStake() public {
//         //Using Account 'A' to stake
//         uint256 stakedAmountBefore = logxStaker.stakedAmounts(address(accountA));
//         uint256 totalDepositSupplyBefore = logxStaker.totalDepositSupply();
//         uint256 balanceBefore = logxStaker.balanceOf(address(accountA));
//         uint256 totalSupplyBefore = logxStaker.totalSupply();


//         vm.startPrank(accountA);
//         logxStaker.stake{value: 50 ether}(50000000000000000000, 10);
//         vm.stopPrank();

//         uint256 stakedAmountAfter = logxStaker.stakedAmounts(address(accountA));
//         uint256 totalDepositSupplyAfter = logxStaker.totalDepositSupply();
//         uint256 balanceAfter = logxStaker.balanceOf(address(accountA));
//         uint256 totalSupplyAfter = logxStaker.totalSupply();

//         assertEq(stakedAmountAfter - stakedAmountBefore, 50000000000000000000);
//         assertEq(totalDepositSupplyAfter - totalDepositSupplyBefore, 50000000000000000000);
//         assertEq(balanceAfter - balanceBefore, 50000000000000000000);
//         assertEq(totalSupplyAfter - totalSupplyBefore, 50000000000000000000);

//         bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
//         bytes32 stakeId = stakeIds[0];
//         uint256 amountStaked = logxStaker.getAmountForStakeId(stakeId);
//         address accountStaked = logxStaker.getAccountForStakeId(stakeId);
//         assertEq(amountStaked, 50000000000000000000);
//         assertEq(accountStaked, address(accountA));
//     }

//     function testUnstake() public {
//         //Using Account 'A' to Stake
//         vm.startPrank(accountA);
//         logxStaker.stake{value: 50 ether}(50000000000000000000, 7);
//         vm.stopPrank();

//         bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
//         bytes32 stakeId = stakeIds[0];
//         //Testing unstake logic 
//         uint256 stakedAmountBefore = logxStaker.stakedAmounts(address(accountA));
//         uint256 totalDepositSupplyBefore = logxStaker.totalDepositSupply();
//         uint256 balanceBefore = logxStaker.balanceOf(address(accountA));
//         uint256 totalSupplyBefore = logxStaker.totalSupply();

//         //Simulate passage of time so staking duration ends
//         vm.warp(8 days);
//         vm.startPrank(accountA);
//         uint256 accruedStakeIdRewards = logxStaker.getStakeIdRewards(stakeId);
//         logxStaker.unstake(stakeId);
//         vm.stopPrank();

//         uint256 stakedAmountAfter = logxStaker.stakedAmounts(address(accountA));
//         uint256 totalDepositSupplyAfter = logxStaker.totalDepositSupply();
//         uint256 balanceAfter = logxStaker.balanceOf(address(accountA));
//         uint256 totalSupplyAfter = logxStaker.totalSupply();

//         assertEq(stakedAmountBefore - stakedAmountAfter, 50000000000000000000);
//         assertEq(totalDepositSupplyBefore - totalDepositSupplyAfter, 50000000000000000000);
//         assertEq(balanceBefore - balanceAfter, 50000000000000000000);
//         assertEq(totalSupplyBefore - totalSupplyAfter, 50000000000000000000);

//         assertEq(accruedStakeIdRewards, 95890410958904109);
//     }

//     function testStakeForAccount() public {
//         address handlerMock = address(150);
//         vm.prank(gov);
//         logxStaker.setHandler(handlerMock, true);

//         //Using Account 'B' to stake for Account 'A'
//         uint256 stakedAmountBefore = logxStaker.stakedAmounts(address(accountA));
//         uint256 totalDepositSupplyBefore = logxStaker.totalDepositSupply();
//         uint256 balanceBefore = logxStaker.balanceOf(address(accountA));
//         uint256 totalSupplyBefore = logxStaker.totalSupply();

//         vm.deal(address(150), 100 ether);
//         vm.prank(address(150));
//         logxStaker.stakeForAccount{value: 50 ether}(accountA, accountA, 50000000000000000000, 10);

//         uint256 stakedAmountAfter = logxStaker.stakedAmounts(address(accountA));
//         uint256 totalDepositSupplyAfter = logxStaker.totalDepositSupply();
//         uint256 balanceAfter = logxStaker.balanceOf(address(accountA));
//         uint256 totalSupplyAfter = logxStaker.totalSupply();

//         assertEq(stakedAmountAfter - stakedAmountBefore, 50000000000000000000);
//         assertEq(totalDepositSupplyAfter - totalDepositSupplyBefore, 50000000000000000000);
//         assertEq(balanceAfter - balanceBefore, 50000000000000000000);
//         assertEq(totalSupplyAfter - totalSupplyBefore, 50000000000000000000);

//         bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
//         bytes32 stakeId = stakeIds[0];
//         uint256 amountStaked = logxStaker.getAmountForStakeId(stakeId);
//         address accountStaked = logxStaker.getAccountForStakeId(stakeId);
//         assertEq(amountStaked, 50000000000000000000);
//         assertEq(accountStaked, address(accountA));
//     }

//     function testUnstakeForAccount() public {
//         vm.prank(gov);
//         address handlerMock = address(150);
//         logxStaker.setHandler(handlerMock, true);

//         //Using Account 'A' to Stake
//         vm.startPrank(accountA);
//         logxStaker.stake{value: 50 ether}(50000000000000000000, 7);
//         vm.stopPrank();

//         bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
//         bytes32 stakeId = stakeIds[0];
//         //Testing unstake logic 
//         uint256 stakedAmountBefore = logxStaker.stakedAmounts(address(accountA));
//         uint256 totalDepositSupplyBefore = logxStaker.totalDepositSupply();
//         uint256 balanceBefore = logxStaker.balanceOf(address(accountA));
//         uint256 totalSupplyBefore = logxStaker.totalSupply();

//         //Simulate passage of time so staking duration ends
//         vm.warp(8 days);
//         vm.prank(address(150));
//         logxStaker.unstakeForAccount(accountA, accountA, stakeId);


//         uint256 stakedAmountAfter = logxStaker.stakedAmounts(address(accountA));
//         uint256 totalDepositSupplyAfter = logxStaker.totalDepositSupply();
//         uint256 balanceAfter = logxStaker.balanceOf(address(accountA));
//         uint256 totalSupplyAfter = logxStaker.totalSupply();

//         assertEq(stakedAmountBefore - stakedAmountAfter, 50000000000000000000);
//         assertEq(totalDepositSupplyBefore - totalDepositSupplyAfter, 50000000000000000000);
//         assertEq(balanceBefore - balanceAfter, 50000000000000000000);
//         assertEq(totalSupplyBefore - totalSupplyAfter, 50000000000000000000);
//     }

//     function testUnstakeBeforeDurationEnd() public {
//         //Using Account 'A' to Stake
//         vm.startPrank(accountA);
//         logxStaker.stake{value: 50 ether}(50000000000000000000, 7);
//         vm.stopPrank();

//         bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
//         bytes32 stakeId = stakeIds[0];

//         vm.startPrank(accountA);
//         vm.expectRevert("LogxStaker: staking duration active");
//         logxStaker.unstake(stakeId);
//         vm.stopPrank();
//     }

//     function testUnstakingWithWrongAccount() public {
//         //Using Account 'A' to Stake
//         vm.startPrank(accountA);
//         logxStaker.stake{value: 50 ether}(50000000000000000000, 7);
//         vm.stopPrank();

//         bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
//         bytes32 stakeId = stakeIds[0];

//         vm.warp(8 days);

//         vm.startPrank(accountB);
//         vm.expectRevert("LogxStaker: invalid _stakeId for _account");
//         logxStaker.unstake(stakeId);
//         vm.stopPrank();
//     }

//     function testClaimTokens() public {
//         //To test for the vesting math, we will deposit
//         // 91.25 tokens for 30 days at 20% APR, earning 1.5 tokens at the end of vesting period
//         //Using Account 'A' to Stake
//         vm.startPrank(accountA);
//         logxStaker.stake{value: 91.25 ether}(91250000000000000000, 30);
//         vm.stopPrank();

//         bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
//         bytes32 stakeId = stakeIds[0];
        
//         //Simulate passage of time so staking duration ends
//         vm.warp(31 days);
//         vm.startPrank(accountA);
//         uint256 accruedAmount = logxStaker.getUnclaimedUserRewards(address(accountA));
//         logxStaker.unstake(stakeId);
//         uint256 amount = logxStaker.claimTokens();
//         vm.stopPrank();

//         assertEq(amount, 1500000000000000000, "Incorrect vested tokens");
//         assertEq(accruedAmount, 1500000000000000000, "Incorrect vested tokens");
//     }

//     function testClaimTokensForAccount() public {
//         vm.prank(gov);
//         address handlerMock = address(150);
//         logxStaker.setHandler(handlerMock, true);

//         //To test for the vesting math, we will deposit
//         // 91.25 tokens for 30 days at 20% APR, earning 1.5 tokens at the end of vesting period
//         //Using Account 'A' to Stake
//         vm.startPrank(accountA);
//         logxStaker.stake{value: 91.25 ether}(91250000000000000000, 30);
//         vm.stopPrank();

//         bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
//         bytes32 stakeId = stakeIds[0];
        
//         //Simulate passage of time so staking duration ends
//         vm.warp(31 days);
//         vm.startPrank(accountA);
//         logxStaker.unstake(stakeId);
//         vm.stopPrank();

//         vm.prank(address(150));
//         uint256 amount = logxStaker.claimTokensForAccount(address(accountA), address(accountA));

//         assertEq(amount, 1500000000000000000, "Incorrect vested tokens");
//     }

//     function testRestake() public {
//         //Normal staking
//         vm.startPrank(accountA);
//         logxStaker.stake{value: 50 ether}(50000000000000000000, 10);
//         vm.stopPrank();

//         bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
//         bytes32 stakeId = stakeIds[0];
        
//         vm.warp(11 days);

//         uint256 stakedAmountBefore = logxStaker.stakedAmounts(address(accountA));
//         uint256 totalDepositSupplyBefore = logxStaker.totalDepositSupply();
//         uint256 balanceBefore = logxStaker.balanceOf(address(accountA));
//         uint256 totalSupplyBefore = logxStaker.totalSupply();

//         vm.startPrank(accountA);
//         logxStaker.restake(stakeId, 15);
//         vm.stopPrank();

//         uint256 stakedAmountAfter = logxStaker.stakedAmounts(address(accountA));
//         uint256 totalDepositSupplyAfter = logxStaker.totalDepositSupply();
//         uint256 balanceAfter = logxStaker.balanceOf(address(accountA));
//         uint256 totalSupplyAfter = logxStaker.totalSupply();

//         assertEq(stakedAmountAfter, stakedAmountBefore, "Incorrect staked amounts");
//         assertEq(totalDepositSupplyAfter, totalDepositSupplyBefore, "Incorrect total deposit supply");
//         assertEq(balanceBefore, balanceAfter, "Incorrect balances");
//         assertEq(totalSupplyBefore, totalSupplyAfter, "Incorrect total supply");

//         (, , uint256 duration, , ) = logxStaker.stakes(stakeId);
//         assertEq(duration, 15, "Incorrect stake duration");
//     }

//     function testRestakeForAccount() public {
//         vm.prank(gov);
//         address handlerMock = address(150);
//         logxStaker.setHandler(handlerMock, true);

//         //Normal staking
//         vm.startPrank(accountA);
//         logxStaker.stake{value: 50 ether}(50000000000000000000, 10);
//         vm.stopPrank();

//         bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
//         bytes32 stakeId = stakeIds[0];
        
//         vm.warp(11 days);

//         uint256 stakedAmountBefore = logxStaker.stakedAmounts(address(accountA));
//         uint256 totalDepositSupplyBefore = logxStaker.totalDepositSupply();
//         uint256 balanceBefore = logxStaker.balanceOf(address(accountA));
//         uint256 totalSupplyBefore = logxStaker.totalSupply();

//         vm.startPrank(address(150));
//         logxStaker.restakeForAccount(address(accountA), stakeId, 15);
//         vm.stopPrank();

//         uint256 stakedAmountAfter = logxStaker.stakedAmounts(address(accountA));
//         uint256 totalDepositSupplyAfter = logxStaker.totalDepositSupply();
//         uint256 balanceAfter = logxStaker.balanceOf(address(accountA));
//         uint256 totalSupplyAfter = logxStaker.totalSupply();

//         assertEq(stakedAmountAfter, stakedAmountBefore, "Incorrect staked amounts");
//         assertEq(totalDepositSupplyAfter, totalDepositSupplyBefore, "Incorrect total deposit supply");
//         assertEq(balanceBefore, balanceAfter, "Incorrect balances");
//         assertEq(totalSupplyBefore, totalSupplyAfter, "Incorrect total supply");

//         (, , uint256 duration, , ) = logxStaker.stakes(stakeId);
//         assertEq(duration, 15, "Incorrect stake duration");
//     }

//     function testZeroDurationStake() public {
//         //To test for the vesting math, we will deposit
//         // 100 tokens staked with 0 duration for 365 days at 3% APR, earning 3 tokens at the end of vesting period
//         //Using Account 'A' to Stake
//         vm.startPrank(accountA);
//         logxStaker.stake{value: 100 ether}(100000000000000000000, 0);
//         vm.stopPrank();

//         bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
//         bytes32 stakeId = stakeIds[0];
        
//         //Simulate passage of time so staking duration ends
//         vm.warp(365 days + 1 seconds);
//         vm.startPrank(accountA);
//         logxStaker.unstake(stakeId);
//         uint256 amount = logxStaker.claimTokens();
//         vm.stopPrank();

//         assertEq(amount, 3000000000000000000, "Incorrect vested tokens");
//     }

//     function testMultipleClaimsWihoutUnstaking() public {
//         //Staking 86400 tokens for 30 days at 20% APR
//         //at the end of day 1, user should earn 0.2 tokens
//         vm.startPrank(accountA);
//         logxStaker.stake{value: 365 ether}(365000000000000000000, 30);
//         vm.stopPrank();
        
//         //Simulate passage of 2 days
//         vm.warp(2 days + 1 seconds);
//         vm.startPrank(accountA);
//         uint256 amount1 = logxStaker.claimTokens();
//         vm.stopPrank();

//         assertEq(amount1, 400000000000000000, "Incorrect vested tokens");

//         //Simulate passage of another 2 days
//         //Note looks like vm.warp does not stack on the previous vm.warp, hence we have to simulate the passage of 4 days
//         vm.warp(4 days + 1 seconds);
//         vm.startPrank(accountA);
//         uint256 amount2 = logxStaker.claimTokens();
//         vm.stopPrank();

//         assertEq(amount2, 400000000000000000, "Incorrect vested tokens");
//     }

//     //Note that this test is primarily being written to find out the amount of gas consumed
//     function testClaimForMultipleStakeIds() public {
//         uint256 stakeCount = 50;
//         //To test for the vesting math, we will deposit
//         // 9.125 tokens for 30 days at 20% APR 10 times, earning 1.5 tokens at the end of vesting period
//         //Using Account 'A' to Stake
//         vm.startPrank(accountA);
//         uint256 singleStakeAmount = 91250000000000000000 / stakeCount;

//         uint256 singleStakeAmountEther = 1.825 ether;
//         for (uint256 i=0; i< stakeCount; i++) {
//             logxStaker.stake{value: singleStakeAmountEther}(singleStakeAmount, 30);
//         }
//         vm.stopPrank();

//         //Simulate passage of time so staking duration ends
//         vm.warp(31 days);
//         vm.startPrank(accountA);
//         uint256 amount = logxStaker.claimTokens();
//         vm.stopPrank();

//         assertEq(amount, 1500000000000000000, "Incorrect vested tokens");
//     }

//     //Note that this test is primarily being written to find out the amount of gas consumed
//     function testUnstakeWithMultipleStakeIds() public {
//         uint256 stakeCount = 50;
//         //To test for the vesting math, we will deposit
//         // 9.125 tokens for 30 days at 20% APR 10 times, earning 1.5 tokens at the end of vesting period
//         //Using Account 'A' to Stake
//         vm.startPrank(accountA);
//         uint256 singleStakeAmount = 91250000000000000000 / stakeCount;
//         uint256 singleStakeAmountEther = 1.825 ether;
//         for (uint256 i=0; i< stakeCount; i++) {
//             logxStaker.stake{value: singleStakeAmountEther}(singleStakeAmount, 30);
//         }
//         vm.stopPrank();

//         bytes32[] memory stakeIds = logxStaker.getUserIds(accountA);
//         //Simulate passage of time so staking duration ends
//         vm.warp(31 days);
//         vm.startPrank(accountA);
//         for (uint256 i=0; i< stakeIds.length; i++) {
//             logxStaker.unstake(stakeIds[i]);
//         }
//         uint256 amount = logxStaker.claimTokens();
//         vm.stopPrank();

//         assertEq(amount, 1500000000000000000, "Incorrect vested tokens");
//     }

//     function testTransferRevert() public {
//         vm.expectRevert("Transfer of staked $LOGX not allowed");
//         logxStaker.transfer(address(0x1), 100);
//     }

//     function testAllowanceRevert() public {
//         vm.expectRevert("Allowance for staked $LOGX not allowed");
//         logxStaker.allowance(address(this), address(0x1));
//     }

//     function testApproveRevert() public {
//         vm.expectRevert("Approvals for staked $LOGX not allowed");
//         logxStaker.approve(address(0x1), 100);
//     }

//     function testTransferFromRevert() public {
//         vm.expectRevert("Transfer From staked $LOGX not allowed");
//         logxStaker.transferFrom(address(this), address(0x1), 100);
//     }
// }