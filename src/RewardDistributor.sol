// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
    @title RewardsDistributor
    @dev questions to answer (to be closed before deployment)  - 
    1. The deployer address will be both admin and gov for this contract ?
    2. Need to double check compatibility with compilers
    3. Need to double check that Interfaces are imported with correct functions, events, etc.
    @dev contract initialisation - 
    1. call updateLastDistributionTime using admin wallet
    2. 
 */

import "../libraries/utils/ReentrancyGuard.sol";
import "../access/Governable.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/math/SafeMath.sol";

//Interfaces
import "./interfaces/IRewardTracker.sol";

contract RewardDistributor is ReentrancyGuard, Governable {
    using SafeERC20 for IERC20;
    
    //SafeMath not needed for compiler version > 0.8, but we need to use sub() function in line 75 of this contract
    using SafeMath for uint256;
    address public admin;
    address public rewardToken;
    uint256 public tokensPerInterval;
    address public rewardTracker;
    uint256 public lastDistributionTime;

    event Distribute(uint256 amount);
    event TokensPerIntervalChange(uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "RewardDistributor: forbidden");
        _;
    }

    constructor(address _rewardToken, address _rewardTracker) {
        rewardToken = _rewardToken;
        rewardTracker = _rewardTracker;
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
        IRewardTracker(rewardTracker).updateRewards();
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
}