// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Logx.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/open-zeppelin/ERC20.sol";

contract ERC20Token is ERC20 {
    constructor(uint256 initialSupply) ERC20("ERC20 Token", "ERC") {
        _mint(msg.sender, initialSupply);
    }
}

contract LogXTest is Test {
    LogX private logX;
    address alice;
    address bob;
    address charlie;
    address deployer;
    address newGov;
    address minter;
    ERC20Token erc20;

    function setUp() public {
        logX = new LogX(100000 * 10 ** 18); // Assuming constructor takes initial supply
        deployer = address(this);
        alice = address(1);
        bob = address(2);
        newGov = address(3);
        minter = address(4);
        charlie = address(5);
        vm.prank(address(this));  // The test contract itself is the initial token holder
        logX.transfer(bob, 500 * 10 ** 18);  // Transfer tokens from deployer to bob
    }

    function testSetGov() public {
        logX.setGov(newGov);
        assertEq(logX.gov(), newGov);
    }

    function testSetWithWrongAddress() public {
        vm.prank(newGov);
        vm.expectRevert("LogX: forbidden");
        logX.setGov(deployer);
    }

    function testSetInfo() public {
        string memory newName = "New LOGX";
        string memory newSymbol = "$NLX";
        logX.setInfo(newName, newSymbol);
        assertEq(logX.name(), newName);
        assertEq(logX.symbol(), newSymbol);
    }

    function testSetInfoWithWrongAddress() public {
        vm.prank(newGov);
        vm.expectRevert("LogX: forbidden");
        logX.setInfo("Fail LOGX", "$FLX");
    }

    function testSetMinter() public {
        logX.setMinter(minter, true);
        assertTrue(logX.isMinter(minter));
    }

    function testSetMinterWithWrongAddress() public {
        vm.prank(newGov);
        vm.expectRevert("LogX: forbidden");
        logX.setMinter(minter, true);
    }

    function testWithdrawToken() public {
        uint256 amount = 1000;
        erc20 = new ERC20Token(1000);

        uint256 balanceInitial = erc20.balanceOf(address(this));
        erc20.transfer(address(logX), 1000);

        uint256 balanceAfterTransfer = erc20.balanceOf(address(this));
        logX.withdrawToken(address(erc20), address(this), amount);

        uint256 balanceAfterWithdraw = erc20.balanceOf(address(this));

        assertEq(balanceInitial, 1000);
        assertEq(balanceAfterTransfer, 0);
        assertEq(balanceAfterWithdraw, 1000);
    }

    function testWithdrawTokenWithWrongAddress() public {
        uint256 amount = 1000;
        erc20 = new ERC20Token(1000);
        vm.prank(newGov);
        vm.expectRevert("LogX: forbidden");
        logX.withdrawToken(address(erc20), deployer, amount);
    }

    function testId() public view {
        assertEq(logX.id(), "$LOGX");
    }

    function testBalanceOf() public view {
        uint256 bobBalance = logX.balanceOf(bob);
        assertEq(bobBalance, 500 * 10 ** 18, "Bob should have 500 * 10**18 tokens");
    }

    function testTransfer() public {
        logX.transfer(bob, 500 * 10 ** 18);
        uint256 bobStartingBalance = logX.balanceOf(bob);
        uint256 aliceStartingBalance = logX.balanceOf(alice);
        vm.prank(bob);
        logX.transfer(alice, 200 * 10 ** 18);
        assertEq(logX.balanceOf(bob), bobStartingBalance - 200 * 10 ** 18, "Test Transfer: Wrong Balance for Bob");
        assertEq(logX.balanceOf(alice), aliceStartingBalance + 200 * 10 ** 18, "Test Transfer: Wrong Balance for Alice");
    }

    function testTransferToSelf() public {
        vm.prank(bob);
        vm.expectRevert("LogX: transfer to self");
        logX.transfer(bob, 100 * 10 ** 18); // This should fail
    }

    function testTransferToZeroAddress() public {
        vm.prank(bob);
        vm.expectRevert("LogX: transfer to the zero address");
        logX.transfer(address(0), 100 * 10 ** 18); // This should fail
    }

    function testApproveAndAllowance() public {
        vm.prank(bob);
        logX.approve(alice, 100 * 10 ** 18);

        assertEq(logX.allowance(bob, alice), 100 * 10 ** 18);
    }

    function testApproveWithZeroAddressOwner() public {
        vm.prank(address(0));
        vm.expectRevert("LogX: approve from the zero address");
        logX.approve(charlie, 100 * 10 ** 18);
    }

    function testApproveToZeroAddress() public {
        vm.expectRevert("LogX: approve to the zero address");
        logX.approve(address(0), 100 * 10 ** 18);
    }

    function testTransferFrom() public {
        uint256 balanceBefore = logX.balanceOf(charlie);
        vm.prank(bob);
        logX.approve(alice, 100 * 10 ** 18);

        vm.prank(alice);
        logX.transferFrom(bob, charlie, 100 * 10 ** 18);
        uint256 balanceAfter = logX.balanceOf(charlie);
        assertEq(balanceBefore, 0);
        assertEq(balanceAfter, 100 * 10 ** 18);
    }

    function testTransferFromToSelf() public {
        vm.startPrank(bob);
        //We give approval from bob to bob to test the flow
        logX.approve(bob, 100 * 10 ** 18);
        vm.expectRevert("LogX: transfer to self");
        logX.transferFrom(bob, bob, 100 * 10 ** 18); // This should fail
        vm.stopPrank();
    }

    function testTransferFromToZeroAddress() public {
        vm.startPrank(bob);
        logX.approve(bob, 100 * 10 ** 18);
        vm.expectRevert("LogX: transfer to the zero address");
        logX.transferFrom(bob, address(0), 100 * 10 ** 18); // This should fail
        vm.stopPrank();
    }

    function testMintAndBurn() public {
        logX.setMinter(minter, true);
        assertTrue(logX.isMinter(minter));

        uint256 charlieBalanceBeforeMint = logX.balanceOf(address(charlie));
        assertEq(charlieBalanceBeforeMint, 0, "Charlie's balance before mint should be 0");
        
        vm.startPrank(minter);
        logX.mint(charlie, 100 * 10 ** 18);
        uint256 charlieBalanceAfterMint = logX.balanceOf(charlie);
        logX.burn(charlie, 50 * 10 ** 18);
        uint256 charlieBalanceAfterBurn = logX.balanceOf(charlie);

        assertEq(charlieBalanceAfterMint, 100 * 10 ** 18, "Charlie's balance after mint should be 0");
        assertEq(charlieBalanceAfterBurn, 50 * 10 ** 18, "Charlie's balance after burn should be 0");
        vm.stopPrank();
    }

    function testMintWithoutMinterAddress() public {
        vm.expectRevert("LogX: forbidden");
        logX.mint(charlie, 100 * 10 ** 18);
    }

    function testMintToZeroAddress() public {
        logX.setMinter(minter, true);
        assertTrue(logX.isMinter(minter));

        vm.startPrank(minter);
        vm.expectRevert("LogX: mint to the zero address");
        logX.mint(address(0), 100 * 10 ** 18);
        vm.stopPrank();

    }

    function testBurnWithoutMinterAddress() public {
        vm.expectRevert("LogX: forbidden");
        logX.burn(charlie, 100 * 10 ** 18);
    }

    function testBurnToZeroAddress() public {
        logX.setMinter(minter, true);
        assertTrue(logX.isMinter(minter));

        vm.startPrank(minter);
        vm.expectRevert("LogX: burn from the zero address");
        logX.burn(address(0), 100 * 10 ** 18);
        vm.stopPrank();
    }
}