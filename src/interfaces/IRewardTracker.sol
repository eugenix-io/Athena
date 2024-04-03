// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IRewardTracker {
    function depositBalances(address _account, address _depositToken) external view returns (uint256);
    function stakedAmounts(address _account) external view returns (uint256);
    function updateRewards() external;
    function stake(address _depositToken, uint256 _amount) external;
    function stakeForAccount(address _fundingAccount, address _account, address _depositToken, uint256 _amount) external;
    function unstake(address _depositToken, uint256 _amount) external;
    function unstakeForAccount(address _account, address _depositToken, uint256 _amount, address _receiver) external;
    function tokensPerInterval() external view returns (uint256);
    function claimRewards(address _receiver) external returns (uint256);
    function claimRewardsForAccount(address _account, address _receiver) external returns (uint256);
    function claimableRewards(address _account) external view returns (uint256);
    function claimVestedTokens() external returns (uint256);
    function claimVestedTokensForAccount(address _account, address _receiver) external returns (uint256);
    function averageStakedAmounts(address _account) external view returns (uint256);
    function cumulativeRewards(address _account) external view returns (uint256);
}