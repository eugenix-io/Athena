// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "../libraries/utils/ReentrancyGuard.sol";
import "../access/Governable.sol";

import "./interfaces/IRewardTracker.sol";

contract RewardRouter is ReentrancyGuard, Governable {

    bool public isInitialized;
    address public logx;
    address public stakedLogxTracker;
    address public govToken;
    VotingPowerType public votingPowerType;

    event StakeLogx(address account, uint256 amount);
    event UnstakeLogx(address account, uint256 amount);

    function initialize(
        address _logx,
        address _stakedLogxTracker,
    ) external onlyGov {
        require(!isInitialized, "RewardRouter: already initialized");
        isInitialized = true;

        logx = _logx
        stakedLogxTracker = _stakedLogxTracker;
    }

    function setVotingPowerType(VotingPowerType _votingPowerType) external onlyGov {
        votingPowerType = _votingPowerType;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    /**
        Staking User Flow
     */
    function stakeLogx(uint256 _amount) external nonReentrant {
        _stakeLogx(msg.sender, msg.sender, logx, _amount);
    }

    function stakeLogxForAccount(address _account, uint256 _amount) external nonReentrant onlyGov {
        _stakeLogx(msg.sender, _account, logx, _amount);
    }

    function batchStakeLogxForAccount(address[] memory _accounts, uin256[] memory _amounts) external nonReentrant onlyGov {
        address _logx = logx;
        for(uint256 i=0; i < _accounts.length; i++) {
            _stakeLogx(msg.sender, _accounts[i], _amounts[i]);
        }
    }

    function _stakeLogx(address _fundingAccount, address _account, address _token, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        IRewardTracker(stakedLogxTracker).stakeForAccount(_fundingAccount, _account, _token, _amount);

        emit StakeLogx(_account, _amount);
    }

    /**
        Unstaking User Flow
     */
    function unstakeLogx(uint256 _amount) external nonReentrant {
        _unstakeLogx(msg.sender, logx, _amount);
    }

    //Question - Do we need an unstakeForAccount function to handle KOL scenario ? 

    function _unstakeLogx(address _account, address _token, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        uint256 balance = IRewardTracker(stakedLogxTracker).stakedAmounts(_account);

        IRewardTracker(stakedLogxTracker).unstakeForAccount(_account, _token, _amount, _account);

        emit UnstakeLogx(_account, _amount);
    }

    /**
        Claim User Flow
     */
    function claimFees() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(stakedLogxTracker).claimForAccount(account, account);
    }
}