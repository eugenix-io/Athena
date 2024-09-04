// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILogxStaker {

    // Governance functions
    function initialize(address logxTokenAddress, string memory _name, string memory _symbol) external;
    function setHandler(address _handler, bool _isActive) external;
    function setCumulativeEarningsRate(uint256 _rate) external;

    // Feature functions
    function stakeForAccount(bytes32 subAccountId, uint256 amount, address receiver) external payable returns (uint256);
    function claimForAccount(bytes32 subAccountId, address receiver) external returns (uint256);
    function unstakeForAccount(bytes32 subAccountId, uint256 amount, address receiver) external returns (uint256);

    // Mappings
    function isHandler(address handler) external view returns (bool);
    function stakes(bytes32 subAccountId) external view returns (uint256 cumulativeEarningsRate, uint256 amount);
}
