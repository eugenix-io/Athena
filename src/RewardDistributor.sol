// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
    @title RewardsDistributor
 */

import "../libraries/utils/ReentrancyGuard.sol";
import "../access/Governable.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/math/SafeMath.sol";

//Interfaces
import "./interfaces/ILogxStaker.sol";

contract RewardDistributor is ReentrancyGuard, Governable {
    using SafeERC20 for IERC20;
    
    //SafeMath not needed for compiler version > 0.8, but we need to use sub() function in line 75 of this contract
    using SafeMath for uint256;
    address public admin;
    address public rewardToken;
    uint256 public tokensPerInterval;
    address public logxStaker;
    uint256 public lastDistributionTime;

    event Distribute(uint256 amount);
    event TokensPerIntervalChange(uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "RewardDistributor: forbidden");
        _;
    }

    constructor(address _rewardToken, address _logxStaker) {
        rewardToken = _rewardToken;
        logxStaker = _logxStaker;
        admin = msg.sender;
    }

    function setAdmin(address _admin) external onlyGov {
        admin = _admin;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function updateLastDistributionTime() external onlyAdmin {
        lastDistributionTime = block.timestamp;
    }

    function setTokensPerInterval(uint256 _amount) external onlyAdmin {
        require(lastDistributionTime != 0, "RewardDistributor: invalid lastDistributionTime");
        ILogxStaker(logxStaker).updateFeeRewards();
        tokensPerInterval = _amount;
        emit TokensPerIntervalChange(_amount);
    }

    function pendingRewards() public view returns (uint256) {
        if (block.timestamp == lastDistributionTime) {
            return 0;
        }

        uint256 timeDiff = block.timestamp.sub(lastDistributionTime);
        return tokensPerInterval.mul(timeDiff);
    }

    function distribute() external returns(uint256) {
        require(msg.sender == logxStaker, "RewardDistributor: invalid msg.sender");
        uint256 amount = pendingRewards();

        if(amount == 0) { return 0; }

        lastDistributionTime = block.timestamp;
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        if(amount > balance) { amount = balance; }

        IERC20(rewardToken).safeTransfer(msg.sender, amount);

        emit Distribute(amount);
        return amount;
    }  
}