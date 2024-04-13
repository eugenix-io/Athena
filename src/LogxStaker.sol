// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
    @title RewardTracker
 */

import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";
import "../access/Governable.sol";

//Interfaces
import "./interfaces/IRewardDistributor.sol";
import "./interfaces/ILogxStaker.sol";

contract LogxStaker is IERC20, ReentrancyGuard, Governable {
    using SafeERC20 for IERC20;

    //Constants
    uint256 public constant PRECISION = 1e30;
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint8 public constant decimals = 18;

    //Global Variables
    string public name;
    string public symbol;
    address public vestingToken;
    address public depositToken;
    address public distributor;
    bool public isInitialized;
    bool public inPrivateTransferMode;
    bool public inPrivateStakingMode;
    bool public inPrivateClaimingMode;
    uint256 public override totalSupply;
    uint256 public totalDepositSupply;
    uint256 public cumulativeFeeRewardPerToken;

    //Mappings
    mapping (address => bool) public isHandler;
    mapping (address => uint256) public balances;
    mapping (address => uint256) public stakedAmounts;
    mapping (address => mapping (address => uint256)) public allowances;
    mapping (address => bytes32[]) public userIds;
    mapping (bytes32 => Stake) public stakes;
    //Note - the Apy values will be stored for duration in days
    mapping (uint256 => uint256) public apyForDuration;
    mapping (address => uint256) public cumulativeVestedTokens;
    mapping (address => uint256) public claimableVestedTokens;
    //ToDo - we could remove user nonce to save gas if needed
    mapping(address => uint256) private userNonces;
    mapping (address => uint256) public previousCumulatedFeeRewardPerToken;
    mapping (address => uint256) public claimableFeeReward;
    mapping (address => uint256) public cumulativeFeeRewards;
    mapping (address => uint256) public averageStakedAmounts;

    //Events
    event Claim(address receiver, address tokenAddress, uint256 amount);

    //Structs
    struct Stake {
        address account;
        uint256 amount;
        //Duration will be stored in days
        uint256 duration;
        uint256 apy;
        //Start timestamp will be the block.timestamp when the user stakes amount
        uint256 startTime;
    }

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function initialize(
        address _vestingToken,
        address _depositToken,
        address _distributor
    ) external onlyGov {
        require(!isInitialized, "LogxStaker: already initialized");
        isInitialized = true;

        vestingToken = _vestingToken;
        depositToken = _depositToken;
        distributor = _distributor;

        //Initialising $LOGX vesting APRs with pre-defined values
        // We add APR values considering the BASIS_POINTS_DIVISOR which is 10^4.
        apyForDuration[7] = 100000;
        apyForDuration[15] = 150000;
        apyForDuration[30] = 200000;
        apyForDuration[60] = 250000;
        apyForDuration[90] = 300000;
    }

    function setInPrivateTransferMode(bool _inPrivateTransferMode) external onlyGov {
        inPrivateTransferMode = _inPrivateTransferMode;
    }

    function setInPrivateStakingMode(bool _inPrivateStakingMode) external onlyGov {
        inPrivateStakingMode = _inPrivateStakingMode;
    }

    function setInPrivateClaimingMode(bool _inPrivateClaimingMode) external onlyGov {
        inPrivateClaimingMode = _inPrivateClaimingMode;
    }

    function setHandler(address _handler, bool _isActive) external onlyGov {
        isHandler[_handler] = _isActive;
    }

    /**
        @dev
        @param duration to be passed as number of days
        @param _apy to be passed considering (including) BASIS_POINTS_DIVISOR which is 10^4
     */
    function setAPRForDurationInDays(uint256 _duration, uint256 _apy) external onlyGov {
        require(_apy > 0, "APR cannot be negative");
        apyForDuration[_duration] = _apy;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function balanceOf(address _account) external view override returns (uint256) {
        return balances[_account];
    }

    function allowance(address _owner, address _spender) external view override returns(uint256) {
        return allowances[_owner][_spender];
    }

    function getAmountForStakeId(bytes32 stakeId) public view returns(uint256) {
        return stakes[stakeId].amount;
    }

    function getAccountForStakeId(bytes32 stakeId) public view returns(address) {
        return stakes[stakeId].account;
    }

    function getUserIds(address _user) public view returns (bytes32[] memory) {
        return userIds[_user];
    }

    function getStake(bytes32 stakeId) public view returns (Stake memory) {
        require(stakes[stakeId].startTime != 0, "Stake does not exist.");
        return stakes[stakeId];
    }

    function updateFeeRewards() external nonReentrant {
        _updateFeeRewards(address(0));
    }

    function rewardToken() public view returns(address) {
        return IRewardDistributor(distributor).rewardToken();
    }

    
    /**
        Approve User Flow
     */
    function approve(address _spender, uint256 _amount) external override returns(bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), "LogxStaker: approve from zero address");
        require(_spender != address(0), "LogxStaker: approve from zero address");

        allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }

    /**
        Transfer User Flow
     */
    function transfer(address _recipient, uint256 _amount) external override returns(bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) external override returns(bool) {
        if(isHandler[msg.sender]) {
            _transfer(_sender, _recipient, _amount);
            return true;
        }

        require(allowances[_sender][msg.sender] >= _amount, "LogxStaker: transfer amount exceeds allowance");
        uint256 nextAllowance = allowances[_sender][msg.sender] - _amount;
        _approve(_sender, msg.sender, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        //ToDo (question) - should we run updateRewards() and updateVesting() when user transfer's their staked $LOGX ?
        require(_sender != address(0), "LogxStaker: transfer from zero address");
        require(_recipient != address(0), "LogxStaker: transfer from zero address");

        if(inPrivateTransferMode) { _validateHandler(); }

        require(balances[_sender] >= _amount, "LogxStaker: transfer amount exceeds balance");
        // ToDo (check) - Performing operation directly since Safemath is inbuilt in soliidty compiler
        balances[_sender] = balances[_sender] - _amount;
        balances[_recipient] = balances[_recipient] + _amount;

        emit Transfer(_sender, _recipient, _amount);
    }

    /**
        Staking User Flow
     */
    /**
        @dev
        @param _deposiToken will be the address of $LOGX token
        @param _amount will be the amount of $LOGX to be staked (denominated in 10 ^ 18)
        @param _duration will be the duration for which _amount will be staked in DAYS
     */
    function stake(address _depositToken, uint256 _amount, uint256 _duration) external nonReentrant {
        if(inPrivateStakingMode) { revert("LogxStaker: staking action not enabled"); }
        _stake(msg.sender, msg.sender, _depositToken, _amount, _duration);
    }

    /**
        @dev
        @param _fundingAccount will be the address of the account sponsoring $LOGX tokens
        @param _account will be the address of the account for which _fundingAccount is sponsoring $LOGX tokens
        @param _depositToken will be the address of $LOGX token
        @param _amount will be the amount of $LOGX to be staked (denominated in 10 ^ 18)
        @param _duration will be the duration for which _amount will be staked in DAYS
     */
    function stakeForAccount(address _fundingAccount, address _account, address _depositToken, uint256 _amount, uint256 _duration) external nonReentrant {
        _validateHandler();
        _stake(_fundingAccount, _account, _depositToken, _amount, _duration);
    }

    function _stake(address _fundingAccount, address _account, address _depositToken, uint256 _amount, uint256 _duration) private {
        require(_amount > 0, "Reward Tracker: invalid amount");
        require(_depositToken == depositToken, "LogxStaker: invalid _depositToken");

        IERC20(_depositToken).safeTransferFrom(_fundingAccount, address(this), _amount);

        _updateFeeRewards(_account);

        stakedAmounts[_account] = stakedAmounts[_account] + _amount;
        totalDepositSupply = totalDepositSupply + _amount;

        _addStake(_account, _amount, _duration);
        _mint(_account, _amount);
    }

    function _mint(address _account, uint256 _amount) internal {
        require(_account != address(0), "Reward Tracker: mint to zero address");

        // ToDo (check) - Performing operation directly since Safemath is inbuilt in solidity compiler
        totalSupply = totalSupply + _amount;
        balances[_account] = balances[_account] + _amount;

        emit Transfer(address(0), _account, _amount);
    }

    /**
        Unstaking User Flow
     */
     /**
        @dev
        @param _deposiToken will be the address of $LOGX token
        @param _stakeId is the ID of the stake which has to be unstaked
     */
    function unstake(address _depositToken, bytes32 _stakeId) external nonReentrant {
        if(inPrivateStakingMode) { revert("LogxStaker: action not enabled"); }
        _unstake(msg.sender, _depositToken, msg.sender, _stakeId);
    }

    /**
        @dev
        @param _account will be the address of the account for which _fundingAccount is sponsoring $LOGX tokens
        @param _depositToken will be the address of $LOGX token
        @param _receiver will be the address which will receive _depositTokens
        @param _stakeId is the ID of the stake which has to be unstaked
     */
    function unstakeForAccount(address _account, address _depositToken, address _receiver, bytes32 _stakeId) external nonReentrant {
        _validateHandler();
        _unstake(_account, _depositToken, _receiver, _stakeId);
    }

    function _unstake(address _account, address _depositToken, address _receiver, bytes32 stakeId) private {
        address accountForStakeId = getAccountForStakeId(stakeId);
        require(accountForStakeId == _account, "LogxStaker: invalid _stakeId for _account");
        require(_depositToken == depositToken, "LogxStaker: invalid _depositToken");
        require(!isStakeActive(stakeId), "LogxStaker: staking duration active");

        _updateFeeRewards(_account);
        //ToDo - Calculate the amount of tokens vested for the user
        _updateVestedRewards(_account, stakeId);

        uint256 amount = getAmountForStakeId(stakeId);
        
        stakedAmounts[_account] = stakedAmounts[_account] - amount;
        totalDepositSupply = totalDepositSupply - amount;

        _removeStake(_account, stakeId);
        _burn(_account, amount);

        IERC20(_depositToken).safeTransfer(_receiver, amount);
    }

    function _burn(address _account, uint256 _amount) internal {
        require(_account != address(0), "LogxStaker: burn from zero address");
        require(balances[_account] >= _amount, "LogxStaker: burn amount exceeds balance");

        // ToDo (check) - Performing operation directly since Safemath is inbuilt in solidity compiler
        balances[_account] = balances[_account] - _amount;
        totalSupply = totalSupply - _amount;

        emit Transfer(_account, address(0), _amount);
    }

    /**
        Claim Rewards User Flow
     */
    function claimFeeRewards(address _receiver) external nonReentrant returns(uint256) {
        if(inPrivateClaimingMode) { revert("RewardTracker: action not enabled"); }
        return _claimFeeRewards(msg.sender, _receiver);
    }

    function claimFeeRewardsForAccount(address _account, address _receiver) external nonReentrant returns (uint256) {
        _validateHandler();
        return _claimFeeRewards(_account, _receiver);
    }

    function claimableFeeRewards(address _account) public view returns (uint256) {
        uint256 stakedAmount = stakedAmounts[_account];
        if(stakedAmount == 0) {
            return claimableFeeReward[_account];
        }
        uint256 supply = totalSupply;
        uint256 pendingRewards = IRewardDistributor(distributor).pendingRewards() * PRECISION;
        uint256 nextCumulativeRewardPerToken = cumulativeFeeRewardPerToken + (pendingRewards / supply);
        return claimableFeeReward[_account] + ((stakedAmount * (nextCumulativeRewardPerToken - previousCumulatedFeeRewardPerToken[_account])) / PRECISION);
    }

    function _claimFeeRewards(address _account, address _receiver) private returns (uint256) {
        _updateFeeRewards(_account);

        uint256 tokenAmount = claimableFeeReward[_account];
        claimableFeeReward[_account] = 0;

        if(tokenAmount > 0) {
            address rewardTokenAddress = rewardToken();
            IERC20(rewardTokenAddress).safeTransfer(_receiver, tokenAmount);
            emit Claim(_account, rewardTokenAddress, tokenAmount);
        }

        return tokenAmount;
    }

    /**
        Claim Vested Tokens User Flow
     */
    function claimVestedTokens() external nonReentrant returns (uint256) {
        return _claimVestedTokens(msg.sender, msg.sender);
    }

    function claimVestedTokensForAccount(address _account, address _receiver) external nonReentrant returns (uint256) {
        _validateHandler();
        return _claimVestedTokens(_account, _receiver);
    }

    function _claimVestedTokens(address _account, address _receiver) private returns (uint256) {
        uint256 amount = claimableVestedTokens[_account];
        claimableVestedTokens[_account] = 0;

        IERC20(vestingToken).safeTransfer(_receiver, amount);
        emit Claim(_account, vestingToken, amount);
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
            return 0;
        }
    }

    function isStakeActive(bytes32 stakeId) public view returns (bool) {
        Stake memory userStake = stakes[stakeId];
        uint256 durationInSeconds = userStake.duration * 1 days;
        return block.timestamp < (userStake.startTime + durationInSeconds);
    }

    function _addStake(address _account, uint256 _amount, uint256 _duration) private {
        uint256 nonce = userNonces[_account]++;
        uint256 startTime = block.timestamp;

        uint256 apy = _getApyForDuration(_duration);

        bytes32 stakeId = keccak256(
            abi.encodePacked(
                _account,
                _amount,
                _duration,
                apy,
                startTime,
                nonce
            )
        );

        stakes[stakeId] = Stake({
            account: _account,
            amount: _amount,
            duration: _duration,
            apy: apy,
            startTime: startTime
        });
        userIds[_account].push(stakeId);
    }

    //Note - this is the most expensive operation in the contract so far, we have to figure ways to make this gas efficient
    function _removeStake(address _account, bytes32 stakeId) private {
        require(stakes[stakeId].startTime != 0, "Stake does not exist.");

        // Delete the stake from the stakes mapping
        delete stakes[stakeId];

        // Remove the stakeId from the userIds[_account] array
        // We can skip the remaining code in the function if we are okay with user's stake IDs accruing over time even after their expiry
        uint256 index;
        bool found = false;
        for (uint256 i = 0; i < userIds[_account].length; i++) {
            if (userIds[_account][i] == stakeId) {
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

    function _updateVestedRewards(address _account, bytes32 stakeId) private {
        //Note - Following checks have been commented out since this function is currently only being called during _unstake
        //  If this function is ever called outside _unstake, we have to add the following, and more checks if needed.
        // if(isStakeActive(stakeId)) { return; }
        // address accountForStakeId = getAccountForStakeId(stakeId);
        // require(accountForStakeId == _account, "LogxStaker: Invalid _account for stakeId");

        Stake memory userStake = stakes[stakeId];
        //ToDo - check for arithmetic overflow / underflow
        uint256 vestedTokens = ( userStake.amount * userStake.apy * userStake.duration ) / ( 365 * 100 * 10000 );
        cumulativeVestedTokens[_account] = cumulativeVestedTokens[_account] + vestedTokens;
        claimableVestedTokens[_account] = claimableVestedTokens[_account] + vestedTokens;
    }

    function _updateFeeRewards(address _account) internal {
        uint256 blockReward = IRewardDistributor(distributor).distribute();
        
        uint256 supply = totalSupply;
        //ToDo (check) - is cumulative reward per token being updated correctly ? when we initialise _cumulativeRewardPerToken, it is initialising with value of 0 ?
        uint256 _cumulativeFeeRewardPerToken = cumulativeFeeRewardPerToken;
        if(supply > 0 && blockReward > 0) {
            // ToDo (check) - Perofrming operation directly since Safemath is inbuilt in solidity compiler
            _cumulativeFeeRewardPerToken = _cumulativeFeeRewardPerToken + (blockReward * PRECISION) / supply;
            cumulativeFeeRewardPerToken = _cumulativeFeeRewardPerToken;
        }
        
        //If cumulative rewards per token is 0, it means that there are no rewards yet
        if(cumulativeFeeRewardPerToken == 0) {
            return;
        }

        if(_account != address(0)) {
            uint256 stakedAmount = stakedAmounts[_account];
            // ToDo (check) - Performing operation directly since Safemath is inbuilt in solidity compiler
            uint256 accountReward = (stakedAmount * (_cumulativeFeeRewardPerToken - previousCumulatedFeeRewardPerToken[_account])) / PRECISION;
            uint256 _claimableFeeReward = claimableFeeReward[_account] + accountReward;

            claimableFeeReward[_account] = _claimableFeeReward;
            previousCumulatedFeeRewardPerToken[_account] = _cumulativeFeeRewardPerToken;

            if(_claimableFeeReward > 0 && stakedAmounts[_account] > 0){
                // ToDo (check) - will cumulativeRewards[_account] be initialised with value of 0?
                uint256 nextCumulativeReward = cumulativeFeeRewards[_account] + accountReward;

                averageStakedAmounts[_account] = (averageStakedAmounts[_account] * cumulativeFeeRewards[_account] / nextCumulativeReward) + (stakedAmount * accountReward / nextCumulativeReward);

                cumulativeFeeRewards[_account] = nextCumulativeReward;
            }
        }
    }
}