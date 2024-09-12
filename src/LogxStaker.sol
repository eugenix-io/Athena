// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

//Interfaces
import "./interfaces/ILogxStaker.sol";

contract LogxStaker is ILogxStaker, IERC20, ReentrancyGuard, Ownable2StepUpgradeable {
    using SafeERC20 for IERC20;

    //Constants
    uint256 public constant PRECISION = 1e12;
    uint8 public constant decimals = 18;

    //Global Variables
    string public name;
    string public symbol;
    address public logxTokenAddress;
    uint256 cumulativeEarningsRate;
    uint256 public totalSupply;

    //Mappings
    mapping (address => bool) public isHandler;
    mapping (bytes32 => Stake) public stakes;
    mapping (address => uint256) public balances;

    //Events
    event Claim(address receiver, uint256 amount);

    struct Stake {
        uint256 cumulativeEarningsRate;
        uint256 amount;
    }

    /**
        Governance functions
     */
    /***
        @dev
        @param _logxTokenAddress $LOGX token address when deploying contract.
        @note we can set the address of $LOGX token ONLY ONCE to prevent attacks, 
            we have to add a setter function if we want to change the token ERC20 address changes in the future
     */

    constructor() {
        _disableInitializers();
    }

    function initialize(address _logxTokenAddress, string memory _name, string memory _symbol) external initializer {
        __Ownable_init(msg.sender);
        logxTokenAddress = _logxTokenAddress;
        name = _name;
        symbol = _symbol;
    }

    function setHandler(address _handler, bool _isActive) external onlyOwner {
        isHandler[_handler] = _isActive;
    }

    /**
        User Handler functions
     */
     /***
    /***
        @dev
        @param _rate current cumulative earning rate $LOGX token
        @note this function determines the rewards to be distributed, can be updated only by handler.
     */
    function setCumulativeEarningsRate(uint256 _rate) external {
        _validateHandler();

        cumulativeEarningsRate = _rate;
    }

    /**
        User Functions functions
     */
     /***
     @dev
     @param subAccountId of the user
     @param amount of LogX ERC20 tokens being staked (denominated in 10^18)
     @param receiver wallet address of the user 
      */
    function stakeForAccount(bytes32 subAccountId, uint256 amount, address receiver) payable external nonReentrant returns (uint256) {
        _validateHandler();
        require(amount > 0, "Reward Tracker: invalid amount");


        // Create a storage reference to the stake
        Stake storage stake = stakes[subAccountId];

        uint256 claimedRewards = 0;

        if (stake.amount == 0) {
            // Stake does not exist for this subaccount, create a new stake
            stake.cumulativeEarningsRate = cumulativeEarningsRate;
            stake.amount = amount;
        } else {
            // Stake already exists, claim rewards and add to the existing stake
            claimedRewards = _claimForAccount(subAccountId, receiver);
            stake.amount += amount;
            stake.cumulativeEarningsRate = cumulativeEarningsRate;
        }
        balances[receiver] = balances[receiver] + amount;
        totalSupply = totalSupply + amount;

        emit Transfer(address(0), receiver, amount);

        return claimedRewards;
    }


    /**
        Feature functions
     */
     /***
     @dev
     @param subAccountId of the user
     @param receiver wallet address of the user 
      */
    function claimForAccount(bytes32 subAccountId, address receiver) external nonReentrant returns(uint256){
        _validateHandler();

        Stake storage stake = stakes[subAccountId];

        if (stake.amount == 0){
            return 0;
        }
        uint256 claimedRewards = _claimForAccount(subAccountId, receiver);

        //Update cumulative earnings rate
        stake.cumulativeEarningsRate = cumulativeEarningsRate;

        return claimedRewards;
    }

    /**
        Feature functions
     */
     /***
     @dev
     @param subAccountId of the user
     @param receiver wallet address of the user 
     @note that this function will transfer $LOGX to user's address whenever a user stakes, unstakes or claims rewards.
      */
    function _claimForAccount(bytes32 subAccountId, address _receiver) private returns(uint256) {
        Stake memory stake = stakes[subAccountId];

        if (cumulativeEarningsRate < stake.cumulativeEarningsRate) {
            emit Claim(_receiver, 0);
            return 0;
        }

        uint256 rewards = (stake.amount * (cumulativeEarningsRate - stake.cumulativeEarningsRate)) / PRECISION;
        emit Claim(_receiver, rewards);
        return rewards;
    }

    /**
        Feature functions
     */
     /***
     @dev
     @param subAccountId of the user
     @param amount of LogX ERC20 tokens being staked (denominated in 10^18)
     @param receiver wallet address of the user 
      */
    function unstakeForAccount(bytes32 subAccountId, uint256 amount, address receiver) external nonReentrant() returns(uint256) {
        _validateHandler();
        require(amount > 0, "Reward Tracker: invalid amount");

        Stake storage stake = stakes[subAccountId];

        // User does not currently have a stake.
        if (stake.amount == 0) {
            return 0;
        } 
        require(stake.amount >= amount, "Invalid unstake amount");
        uint256 claimedRewards = _claimForAccount(subAccountId, receiver);
        stake.cumulativeEarningsRate = cumulativeEarningsRate;
        stake.amount -= amount;

        balances[receiver] = balances[receiver] - amount;
        totalSupply = totalSupply - amount;

        emit Transfer(receiver, address(0), amount);

        return claimedRewards;
    }

    /**
        Utility functions
     */
    function _validateHandler() internal view {
        require(isHandler[msg.sender], "LogxStaker : handler validation");
    }

    function balanceOf(address _account) external view returns (uint256) {
        return balances[_account];
    }

    //@note ERC20 contract functions that are not supported on staked $LOGX token
    //      These functions can be updated in a later version to dictate network economy.
    function transfer(address recipient, uint256 amount) external returns (bool) {
        revert("stLogX transfer not allowed");
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        revert("stLogX allowance not allowed");
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        revert("stLogX approve not allowed");
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        revert("stLogX transferFrom not allowed");
    }
}   
