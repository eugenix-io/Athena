// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface ILogxStaker {
    // Function signatures
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function initialize(address vestingToken, address depositToken, address distributor) external;
    function setInPrivateTransferMode(bool _inPrivateTransferMode) external;
    function setInPrivateStakingMode(bool _inPrivateStakingMode) external;
    function setInPrivateClaimingMode(bool _inPrivateClaimingMode) external;
    function setHandler(address handler, bool isActive) external;
    function setAPRForDurationInDays(uint256 duration, uint256 apy) external;
    function withdrawToken(address token, address account, uint256 amount) external;

    function getAmountForStakeId(bytes32 stakeId) external view returns (uint256);
    function getAccountForStakeId(bytes32 stakeId) external view returns (address);
    function getUserIds(address user) external view returns (bytes32[] memory);
    function getStake(bytes32 stakeId) external view returns (Stake memory);
    function updateFeeRewards() external;

    function stake(address depositToken, uint256 amount, uint256 duration) external;
    function stakeForAccount(address fundingAccount, address account, address depositToken, uint256 amount, uint256 duration) external;
    function unstake(address depositToken, bytes32 stakeId) external;
    function unstakeForAccount(address account, address depositToken, address receiver, bytes32 stakeId) external;
    function claimVestedTokens() external returns (uint256);
    function claimVestedTokensForAccount(address account, address receiver) external returns (uint256);

    // Structs used within the functions
    struct Stake {
        address account;
        uint256 amount;
        uint256 duration;
        uint256 apy;
        uint256 startTime;
    }
}
