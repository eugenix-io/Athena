// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";
import "../access/Governable.sol";

//Interfaces
import "./interfaces/ILogxStaker.sol";

contract LogxStaker is ILogxStaker, IERC20, ReentrancyGuard, Governable {
    using SafeERC20 for IERC20;

    //Constants
    uint256 public constant PRECISION = 1e12;
    uint8 public constant decimals = 18;

    //Global Variables
    string public name;
    string public symbol;
    bool public isInitialized;
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

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    /**
        Governance functions
     */
    // NOTE - we can probably remove this initialisation function
    function initialize(uint256 _apy) external onlyGov {
        require(!isInitialized, "LogxStaker: already initialized");
        isInitialized = true;
    }

    function setHandler(address _handler, bool _isActive) external onlyGov {
        isHandler[_handler] = _isActive;
    }

    function setCumulativeEarningsRate(uint256 _rate) external {
        _validateHandler();

        cumulativeEarningsRate = _rate;
    }

    /**
        Feature functions
     */
    function stakeForAccount(bytes32 subAccountId, uint256 amount, address receiver) payable external nonReentrant returns (uint256) {
        _validateHandler();
        require(amount > 0, "Reward Tracker: invalid amount");
        require(msg.value == amount, "LogxStaker: msg.value != amount");

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

        return claimedRewards;
    }


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

    function _claimForAccount(bytes32 subAccountId, address _receiver) private returns(uint256) {
        Stake memory stake = stakes[subAccountId];

        uint256 rewards = (stake.amount * (cumulativeEarningsRate - stake.cumulativeEarningsRate)) / PRECISION;
        (bool success,) = payable(_receiver).call{value: rewards}("");
        require(success, "LogX claimed");
        emit Claim(_receiver, rewards);

        return rewards;
    }

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

    //ERC20 contract functions which are not supported on staked $LOGX token
    //ToDo - we have to figure out if wallets will show st$LOGX as an ERC20 contract even if 
    //  LogxStaker is an abstract contract without the following functions - transfer, allowance, approve, transferFrom
    function transfer(address recipient, uint256 amount) external returns (bool) {
        revert("Transfer of staked $LOGX not allowed");
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        revert("Allowance for staked $LOGX not allowed");
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        revert("Approvals for staked $LOGX not allowed");
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        revert("Transfer From staked $LOGX not allowed");
    }
}   