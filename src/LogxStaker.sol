// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
    @title LogxStaker
 */

import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";
import "../access/Governable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

//Interfaces
import "./interfaces/ILogxStaker.sol";

contract LogxStaker is IERC20, ILogxStaker, ReentrancyGuard, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    //Constants
    uint256 public constant PRECISION = 1e12;
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 constant YEAR_IN_SECONDS = 365 days;

    uint8 public constant decimals = 18;

    //Global Variables
    string public name;
    string public symbol;
    uint256 public totalSupply;
    uint256 public totalDepositSupply;
    uint256 public cumulativeFeeRewardPerToken;

    //Mappings
    mapping (address => bool) public isHandler;
    mapping (address => uint256) public balances;
    mapping (bytes32 => uint256) public stakedAmounts;
    mapping (bytes32 => bytes32[]) public userIds;
    mapping (bytes32 => Stake) public stakes;
    //Note - the Apy values will be stored for duration in days
    mapping (uint256 => uint256) public apyForDuration;
    mapping (bytes32 => uint256) public cumulativeTokens;
    mapping (bytes32 => uint256) public claimableTokens;
    mapping(bytes32 => uint256) private lastRewardsTime;

    //Events
    event Claim(bytes32 receiver, uint256 amount);

    //Structs
    struct Stake {
        bytes32 account;
        //Amount will be stored in 10^18 terms
        uint256 amount;
        //Duration will be stored in days
        uint256 duration;
        //Apy will be stored in 10^4 bps terms
        uint256 apy;
        //Start timestamp will be the block.timestamp when the user stakes amount
        uint256 startTime;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(string calldata _name, string calldata _symbol) external initializer {
        __Ownable_init(msg.sender);
        //Initialising $LOGX vesting APRs with pre-defined values
        // We add APR values considering the BASIS_POINTS_DIVISOR which is 10^4.
        name = _name;
        symbol = _symbol;
        apyForDuration[0] = 30000;
        apyForDuration[7] = 100000;
        apyForDuration[15] = 150000;
        apyForDuration[30] = 200000;
        apyForDuration[60] = 250000;
        apyForDuration[90] = 300000;
    }

    function setHandler(address _handler, bool _isActive) external onlyOwner {
        require(_handler != address(0), "Handler cannot be zero address");
        isHandler[_handler] = _isActive;
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

    /**
        @dev
        @param duration to be passed as number of days
        @param _apy to be passed considering (including) BASIS_POINTS_DIVISOR which is 10^4
     */
    function setAPRForDurationInDays(uint256 _duration, uint256 _apy) external onlyOwner {
        require(_apy > 0, "APR cannot be negative");
        apyForDuration[_duration] = _apy;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function balanceOf(address _account) external view returns (uint256) {
        return balances[_account];
    }

    function getAmountForStakeId(bytes32 stakeId) public view returns(uint256) {
        return stakes[stakeId].amount;
    }

    function getAccountForStakeId(bytes32 stakeId) public view returns(bytes32) {
        return stakes[stakeId].account;
    }

    function getUserIds(bytes32 _user) public view returns (bytes32[] memory) {
        return userIds[_user];
    }

    /**
        Utility functions to get eligible rewards
     */
    function _getAccruedRewards(bytes32 stakeId) internal view returns (uint256) {
        Stake memory userStake = stakes[stakeId];

        uint256 stakeDurationEndTimestamp = userStake.startTime + (userStake.duration * 1 days);
        uint256 stakeDurationStartTimestamp = userStake.startTime;

        uint256 duration = block.timestamp >= stakeDurationEndTimestamp ? (userStake.duration * 1 days) : block.timestamp - stakeDurationStartTimestamp;

        // Calculate reward tokens
        uint256 rewardTokens = (userStake.amount * userStake.apy * duration) / (YEAR_IN_SECONDS * 100 * BASIS_POINTS_DIVISOR);
        return rewardTokens;
    }

    function getUnclaimedUserRewards(bytes32 _account) external view returns (uint256) {
        bytes32[] memory userStakeIds = userIds[_account];
        uint256 accruedRewards;
        for(uint256 i=0; i < userStakeIds.length; i++) {
            accruedRewards = accruedRewards + _getUnclaimedRewards(userStakeIds[i]);
        }
        return accruedRewards;
    }

    function _getUnclaimedRewards(bytes32 stakeId) internal view returns(uint256) {
        Stake memory userStake = stakes[stakeId];
        uint256 stakeDurationEndTimestamp = userStake.startTime + (userStake.duration * 1 days);
        uint256 lastRewardDistributionTime = lastRewardsTime[stakeId];

        uint256 duration = block.timestamp - lastRewardDistributionTime;
        if(userStake.duration != 0 && block.timestamp >= stakeDurationEndTimestamp) {
            duration = lastRewardDistributionTime >= stakeDurationEndTimestamp ? 0 : (stakeDurationEndTimestamp - lastRewardDistributionTime);
        }
        uint256 rewardTokens = (userStake.amount * userStake.apy * duration) / (YEAR_IN_SECONDS * 100 * BASIS_POINTS_DIVISOR);
        return rewardTokens;
    }

    function getStakeIdRewards(bytes32 stakeId) external view returns (uint256) {
        return _getAccruedRewards(stakeId);
    }

    /**
        Staking User Flow
     */

    /**
        @dev
        @param _fundingAccount will be the address of the account sponsoring $LOGX tokens
        @param _account will be the address of the account for which _fundingAccount is sponsoring $LOGX tokens
        @param _amount will be the amount of $LOGX to be staked (denominated in 10 ^ 18)
        @param _duration will be the duration for which _amount will be staked in DAYS
     */
    function stakeForAccount(address _fundingAccount, bytes32 _account, uint256 _amount, uint256 _duration, uint256 _startTime, uint256 nonce) external nonReentrant {
        _validateHandler();
        _stake(_fundingAccount, _account, _amount, _duration, _startTime, nonce);
    }

    function _stake(address _fundingAccount, bytes32 _account, uint256 _amount, uint256 _duration, uint256 _startTime, uint256 nonce) private {
        require(_amount > 0, "Reward Tracker: invalid amount");

        stakedAmounts[_account] = stakedAmounts[_account] + _amount;
        totalDepositSupply = totalDepositSupply + _amount;

        _addStake(_account, _amount, _duration, _startTime, nonce);
        //ToDo - Since during mint we are depositing the st LogX tokens to funding account, the expectation here is that
        // the tokens to be burnt during unstake are also held by the receiver.
        _mint(_fundingAccount, _amount);
    }

    function _mint(address _account, uint256 _amount) internal {
        require(_account != address(0), "Reward Tracker: mint to zero address");

        totalSupply = totalSupply + _amount;
        balances[_account] = balances[_account] + _amount;

        emit Transfer(address(0), _account, _amount);
    }

    /**
        Unstaking User Flow
     */

    /**
        @dev
        @param _account will be the address of the account for which _fundingAccount is sponsoring $LOGX tokens
        @param _receiver will be the address which will receive LogX tokens
        @param _stakeId is the ID of the stake which has to be unstaked
     */
    function unstakeForAccount(bytes32 _account, address _receiver, bytes32 _stakeId) external nonReentrant returns(uint256){
        _validateHandler();
        return _unstake(_account, _receiver, _stakeId);
    }

    function _unstake(bytes32 _account, address _receiver, bytes32 stakeId) private returns(uint256) {
        require(!isStakeActive(stakeId), "LogxStaker: staking duration active");
        bytes32 accountForStakeId = getAccountForStakeId(stakeId);
        require(accountForStakeId == _account, "LogxStaker: invalid _stakeId for _account");

        _updateRewards(_account, stakeId);

        uint256 amount = getAmountForStakeId(stakeId);
        
        stakedAmounts[_account] = stakedAmounts[_account] - amount;
        totalDepositSupply = totalDepositSupply - amount;

        _removeStake(_account, stakeId);
        //Note - the staked LogX tokens are minted to funding account and not the user.
        _burn(_receiver, amount);

        return amount;
    }

    function _burn(address _account, uint256 _amount) internal {
        require(_account != address(0), "LogxStaker: burn from zero address");
        require(balances[_account] >= _amount, "LogxStaker: burn amount exceeds balance");

        balances[_account] = balances[_account] - _amount;
        totalSupply = totalSupply - _amount;

        emit Transfer(_account, address(0), _amount);
    }

    /**
        Re-staking User Flow
     */

    function restakeForAccount(bytes32 _account, bytes32 _stakeId, uint256 _duration) external nonReentrant {
        _validateHandler();
        _restake(_account, _stakeId, _duration);
    }

    function _restake(bytes32 _account, bytes32 _stakeId, uint256 _duration) private {
        bytes32 accountForStakeId = getAccountForStakeId(_stakeId);
        require(accountForStakeId == _account, "LogxStaker: invalid _stakeId for _account");
        require(!isStakeActive(_stakeId), "LogxStaker: staking duration active");

        _updateRewards(_account, _stakeId);
        _updateStake(_stakeId, _duration);
    }

    /**
        Claim Tokens User Flow
     */

    function claimTokensForAccount(bytes32 _account, address _receiver) external nonReentrant returns (uint256) {
        _validateHandler();
        return _claimTokens(_account, _receiver);
    }

    function _claimTokens(bytes32 _account, address _receiver) private returns (uint256) {    
        bytes32[] memory userStakeIds = userIds[_account];
        for(uint256 i=0; i < userStakeIds.length; i++) {
            _updateRewards(_account, userStakeIds[i]);
        }

        uint256 amount = claimableTokens[_account];
        claimableTokens[_account] = 0;

        (bool success,) = payable(_receiver).call{value: amount}("");
        require(success, "LogX claimed");
        emit Claim(_account, amount);
        return amount;
    }

    /**
        Utility functions
     */
    function _validateHandler() private view {
        require(isHandler[msg.sender], "RewardTracker : handler validation");
    }

    function _getApyForDuration(uint256 _duration) internal view returns (uint256){
        if (_duration >= 90) {
            return apyForDuration[90];
        } else if (_duration >= 60) {
            return apyForDuration[60];
        } else if (_duration >= 30) {
            return apyForDuration[30];
        } else if (_duration >= 15) {
            return apyForDuration[15];
        } else if (_duration >= 7) {
            return apyForDuration[7];
        } else {
            return apyForDuration[0];
        }
    }

    function isStakeActive(bytes32 stakeId) public view returns (bool) {
        Stake memory userStake = stakes[stakeId];
        uint256 durationInSeconds = userStake.duration * 1 days;
        return block.timestamp < (userStake.startTime + durationInSeconds);
    }

    function _addStake(bytes32 _account, uint256 _amount, uint256 _duration, uint256 _startTime, uint256 nonce) private {
        uint256 apy = _getApyForDuration(_duration);

        bytes32 stakeId = keccak256(
            abi.encodePacked(
                _account,
                _amount,
                _duration,
                apy,
                _startTime,
                nonce
            )
        );

        stakes[stakeId] = Stake({
            account: _account,
            amount: _amount,
            duration: _duration,
            apy: apy,
            startTime: _startTime
        });
        userIds[_account].push(stakeId);
        lastRewardsTime[stakeId] = block.timestamp;
    }   

    //Note - think of ways to make this function more gas efficient
    function _removeStake(bytes32 _account, bytes32 _stakeId) private {
        require(stakes[_stakeId].startTime != 0, "Stake does not exist.");

        // Delete the stake from the stakes mapping
        delete stakes[_stakeId];

        uint256 index;
        bool found = false;
        for (uint256 i = 0; i < userIds[_account].length; i++) {
            if (userIds[_account][i] == _stakeId) {
                index = i;
                found = true;
                break;
            }
        }

        if (found) {
            userIds[_account][index] = userIds[_account][userIds[_account].length - 1];
            userIds[_account].pop();
        } else {
            revert("Stake ID not found for the account.");
        }
    }

    function _updateStake(bytes32 _stakeId, uint256 _duration) private {
        require(stakes[_stakeId].startTime != 0, "Stake does not exist");

        uint256 startTime = block.timestamp;
        uint256 apy = _getApyForDuration(_duration);

        stakes[_stakeId].duration = _duration;
        stakes[_stakeId].apy = apy;
        stakes[_stakeId].startTime = startTime;

        lastRewardsTime[_stakeId] = block.timestamp;
    }

    //Note - following is the most important function in the contract.
    function _updateRewards(bytes32 _account, bytes32 stakeId) private {
        Stake memory userStake = stakes[stakeId];
        
        uint256 stakeDurationEndTimestamp = userStake.startTime + (userStake.duration * 1 days);
        uint256 lastRewardDistributionTime = lastRewardsTime[stakeId];
        lastRewardsTime[stakeId] = block.timestamp;

        uint256 duration = block.timestamp - lastRewardDistributionTime;
        if(userStake.duration != 0 && block.timestamp >= stakeDurationEndTimestamp) {
            duration = lastRewardDistributionTime >= stakeDurationEndTimestamp ? 0 : (stakeDurationEndTimestamp - lastRewardDistributionTime);
        }
        
        //ToDo - check for precision issues
        uint256 rewardTokens = ( userStake.amount * userStake.apy * duration ) / ( YEAR_IN_SECONDS * 100 * BASIS_POINTS_DIVISOR);
        cumulativeTokens[_account] = cumulativeTokens[_account] + rewardTokens;
        claimableTokens[_account] = claimableTokens[_account] + rewardTokens;
    }

    function withdrawLogX(uint256 amount, address payable account) external onlyOwner {
        // Transfer native LogX to account
        (bool success, ) = payable(account).call{value: amount}("");
        require(success, "LogX Withdraw Failed");
    }

    receive() external payable{}
}