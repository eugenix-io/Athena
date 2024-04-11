// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
    @title RewardTracker
 */

import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";

import "./interfaces/IRewardTracker.sol";
import "../access/Governable.sol";

contract RewardTracker is IERC20, ReentrancyGuard, IRewardTracker, Governable {
    using SafeERC20 for IERC20;

    //Constants
    uint256 public constant PRECISION = 1e30;
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint8 public constant decimals = 18;

    //Global Variables
    string public name;
    string public symbol;
    
}