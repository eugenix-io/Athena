// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILogxStaker {
    // Function declarations from LogxStaker contract

    // Initialization and configuration
    function initialize(address _depositToken) external;
    function setInPrivateTransferMode(bool _inPrivateTransferMode) external;
    function setInPrivateStakingMode(bool _inPrivateStakingMode) external;
    function setInPrivateClaimingMode(bool _inPrivateClaimingMode) external;
    function setHandler(address _handler, bool _isActive) external;
    function setAPRForDurationInDays(uint256 _duration, uint256 _apy) external;
    function withdrawToken(address _token, address _account, uint256 _amount) external;

    // Token balance and staking
    function stake(address _depositToken, uint256 _amount, uint256 _duration) external;
    function stakeForAccount(address _fundingAccount, address _account, address _depositToken, uint256 _amount, uint256 _duration) external;
    function unstake(address _depositToken, bytes32 _stakeId) external;
    function unstakeForAccount(address _account, address _depositToken, address _receiver, bytes32 _stakeId) external;
    function restake(address _depositToken, bytes32 _stakeId, uint256 _duration) external;
    function restakeForAccount(address _account, address _depositToken, bytes32 _stakeId, uint256 _duration) external;

    // Token claiming
    function claimTokens() external returns (uint256);
    function claimTokensForAccount(address _account, address _receiver) external returns (uint256);

    // View functions for stakes and user IDs
    function getAmountForStakeId(bytes32 stakeId) external view returns(uint256);
    function getAccountForStakeId(bytes32 stakeId) external view returns(address);
    function getUserIds(address _user) external view returns (bytes32[] memory);
}
