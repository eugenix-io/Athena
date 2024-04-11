// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRewardTracker {
    function initialize(address _vestingToken, address _depositToken) external;
    function setInPrivateTransferMode(bool _inPrivateTransferMode) external;
    function setInPrivateStakingMode(bool _inPrivateStakingMode) external;
    function setInPrivateClaimingMode(bool _inPrivateClaimingMode) external;
    function setHandler(address _handler, bool _isActive) external;
    function setAPRForDurationInDays(uint256 _duration, uint256 _apy) external;
    function withdrawToken(address _token, address _account, uint256 _amount) external;
    function balanceOf(address _account) external view returns (uint256);
    function allowance(address _owner, address _spender) external view returns (uint256);
    function approve(address _spender, uint256 _amount) external returns (bool);
    function transfer(address _recipient, uint256 _amount) external returns (bool);
    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool);
    function stake(address _depositToken, uint256 _amount, uint256 _duration) external;
    function stakeForAccount(address _fundingAccount, address _account, address _depositToken, uint256 _amount, uint256 _duration) external;
    function unstake(address _depositToken, bytes32 _stakeId) external;
    function unstakeForAccount(address _account, address _depositToken, address _receiver, bytes32 _stakeId) external;
    function claimVestedTokens() external returns (uint256);
    function claimVestedTokensForAccount(address _account, address _receiver) external returns (uint256);
    function getAmountForStakeId(bytes32 stakeId) external view returns(uint256);
    function getAccountForStakeId(bytes32 stakeId) external view returns(address);
}