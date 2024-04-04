// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
    @title RewardTracker
 */

import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";

import "./interfaces/IRewardDistributor.sol";
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
    address public distributor;
    address public vestingToken;
    bool public isInitialized;
    bool public inPrivateTransferMode;
    bool public inPrivateStakingMode;
    bool public inPrivateClaimingMode;
    //ToDo - add a variabe to enable / disable vesting
    uint256 public override totalSupply;
    uint256 public cumulativeRewardPerToken;
    uint256 public vestingDuration;

    //Mappings
    mapping (address => bool) public isDepositToken;
    mapping (address => bool) public isHandler;
    mapping (address => uint256) public balances;
    mapping (address => uint256) public override stakedAmounts;
    mapping (address => uint256) public totalDepositSupply;
    mapping (address => uint256) public previousCumulatedRewardPerToken;
    mapping (address => uint256) public claimableReward;
    mapping (address => uint256) public override cumulativeRewards;
    mapping (address => uint256) public override averageStakedAmounts;
    mapping (address => mapping (address => uint256)) public override depositBalances;
    mapping (address => mapping (address => uint256)) public allowances;
    mapping (address => uint256) public lastVestingTimes;
    mapping (address => uint256) public cumulativeVestedClaimAmounts;
        mapping (address => uint256) public claimedVestedAmounts;

    //Events
    event Claim(address receiver, address tokenAddress, uint256 amount);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function initialize(
        address[] memory _depositTokens,
        address _distributor,
        uint256 _vestingDuration,
        address _vestingToken
    ) external onlyGov {
        require(!isInitialized, "RewardTracker: already initialized");
        isInitialized = true;

        for (uint256 i = 0; i < _depositTokens.length; i++) {
            address depositToken = _depositTokens[i];
            isDepositToken[depositToken] = true;
        }

        distributor = _distributor;
        vestingDuration = _vestingDuration;
        //ToDo - vesting token in the reward tracker is the same as deposit token = $LOGX,
        //  we can remove the deposit token array and replace it with a single logxToken address across the contract
        vestingToken = _vestingToken;
    }

    function setDepositToken(address _depositToken, bool _isDepositToken) external onlyGov {
        isDepositToken[_depositToken] = _isDepositToken;
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

    function tokensPerInterval() external override view returns(uint256) {
        return IRewardDistributor(distributor).tokensPerInterval();
    }

    function updateRewards() external override nonReentrant {
        _updateRewards(address(0));
    }

    function rewardToken() public view returns(address) {
        return IRewardDistributor(distributor).rewardToken();
    }

    /**
        Staking User Flow
     */
    function stake(address _depositToken, uint256 _amount) external override nonReentrant {
        if(inPrivateStakingMode) { revert("RewardTracker: staking action not enabled"); }
        _stake(msg.sender, msg.sender, _depositToken, _amount);
    }

    //ToDo - need to handle KOL vesting scenario in the following function
    function stakeForAccount(address _fundingAccount, address _account, address _depositToken, uint256 _amount) external override nonReentrant {
        _validateHandler();
        _stake(_fundingAccount, _account, _depositToken, _amount);
    }

    function _stake(address _fundingAccount, address _account, address _depositToken, uint256 _amount) private {
        require(_amount > 0, "Reward Tracker: invalid amount");
        require(isDepositToken[_depositToken], "RewardTracker: invalid _depositToken");

        IERC20(_depositToken).safeTransferFrom(_fundingAccount, address(this), _amount);

        _updateRewards(_account);
        _updateVesting(_account);

        // ToDo (check) - Performing operation directly since Safemath is inbuilt in soliidty compiler
        stakedAmounts[_account] = stakedAmounts[_account] + _amount;
        depositBalances[_account][_depositToken] = depositBalances[_account][_depositToken] + _amount;
        totalDepositSupply[_depositToken] = totalDepositSupply[_depositToken] + _amount;

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
    function unstake(address _depositToken, uint256 _amount) external override nonReentrant {
        if(inPrivateStakingMode) { revert("RewardTracker: action not enabled"); }
        _unstake(msg.sender, _depositToken, _amount, msg.sender);
    }

    function unstakeForAccount(address _account, address _depositToken, uint256 _amount, address _receiver) external override nonReentrant {
        _validateHandler();
        _unstake(_account, _depositToken, _amount, _receiver);
    }

    function _unstake(address _account, address _depositToken, uint256 _amount, address _receiver) private {
        require(_amount > 0, "Reward Tracker: invalid amount");
        require(isDepositToken[_depositToken], "RewardTracker: invalid _depositToken");

        _updateRewards(_account);
        _updateVesting(_account);

        uint256 stakedAmount = stakedAmounts[_account];
        require(stakedAmount >= _amount, "RewardTracker: _amount exceeds stakedAmount");

        // ToDo (check) - Performing operation directly since Safemath is inbuilt in solidity compiler        
        stakedAmounts[_account] = stakedAmounts[_account] - _amount;

        uint256 depositBalance = depositBalances[_account][_depositToken];
        require(depositBalance >= _amount, "RewardTracker: _amount exceeds depositBalance");
        // ToDo (check) - Performing operation directly since Safemath is inbuilt in solidity compiler
        depositBalances[_account][_depositToken] = depositBalances[_account][_depositToken] - _amount;
        totalDepositSupply[_depositToken] = totalDepositSupply[_depositToken] - _amount;

        _burn(_account, _amount);
        IERC20(_depositToken).safeTransfer(_receiver, _amount);
    }

    function _burn(address _account, uint256 _amount) internal {
        require(_account != address(0), "RewardTracker: burn from zero address");
        require(balances[_account] >= _amount, "RewardTracker: burn amount exceeds balance");

        // ToDo (check) - Performing operation directly since Safemath is inbuilt in solidity compiler
        balances[_account] = balances[_account] - _amount;
        totalSupply = totalSupply - _amount;

        emit Transfer(_account, address(0), _amount);
    }

    /**
        Approve User Flow
     */
    function approve(address _spender, uint256 _amount) external override returns(bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), "RewardTracker: approve from zero address");
        require(_spender != address(0), "RewardTracker: approve from zero address");

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

    //ToDo (question)- this function gives the ability to the handler to transfer tokens from any account to any account
    function transferFrom(address _sender, address _recipient, uint256 _amount) external override returns(bool) {
        if(isHandler[msg.sender]) {
            _transfer(_sender, _recipient, _amount);
            return true;
        }

        require(allowances[_sender][msg.sender] >= _amount, "RewardTracker: transfer amount exceeds allowance");
        uint256 nextAllowance = allowances[_sender][msg.sender] - _amount;
        _approve(_sender, msg.sender, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        //ToDo (question) - should we run updateRewards() and updateVesting() when user transfer's their staked $LOGX ?
        require(_sender != address(0), "RewardTracker: transfer from zero address");
        require(_recipient != address(0), "RewardTracker: transfer from zero address");

        if(inPrivateTransferMode) { _validateHandler(); }

        require(balances[_sender] >= _amount, "RewardTracker: transfer amount exceeds balance");
        // ToDo (check) - Performing operation directly since Safemath is inbuilt in soliidty compiler
        balances[_sender] = balances[_sender] - _amount;
        balances[_recipient] = balances[_recipient] + _amount;

        emit Transfer(_sender, _recipient, _amount);
    }

    /**
        Claim Rewards User Flow
     */
    function claimRewards(address _receiver) external nonReentrant returns(uint256) {
        if(inPrivateClaimingMode) { revert("RewardTracker: action not enabled"); }
        return _claimRewards(msg.sender, _receiver);
    }

    function claimRewardsForAccount(address _account, address _receiver) external nonReentrant returns (uint256) {
        _validateHandler();
        return _claimRewards(_account, _receiver);
    }

    function claimableRewards(address _account) public view returns (uint256) {
        uint256 stakedAmount = stakedAmounts[_account];
        if(stakedAmount == 0) {
            return claimableReward[_account];
        }
        uint256 supply = totalSupply;
        uint256 pendingRewards = IRewardDistributor(distributor).pendingRewards() * PRECISION;
        uint256 nextCumulativeRewardPerToken = cumulativeRewardPerToken + (pendingRewards / supply);
        return claimableReward[_account] + ((stakedAmount * (nextCumulativeRewardPerToken - previousCumulatedRewardPerToken[_account])) / PRECISION);
    }

    function _claimRewards(address _account, address _receiver) private returns (uint256) {
        _updateRewards(_account);

        uint256 tokenAmount = claimableReward[_account];
        claimableReward[_account] = 0;

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
        _updateVesting(_account);
        uint256 amount = claimableVestedTokens(_account);
        claimedVestedAmounts[_account] = claimedVestedAmounts[_account] + amount;

        IERC20(vestingToken).safeTransfer(_receiver, amount);
        emit Claim(_account, vestingToken, amount);
        return amount;
    }

    function claimableVestedTokens(address _account) public view returns (uint256) {
        uint256 amount = cumulativeVestedClaimAmounts[_account] - claimedVestedAmounts[_account];
        uint256 nextClaimable = _getNextClaimableVestingAmount(_account);
        return amount + nextClaimable;
    }

    /**
        Utility functions
     */
    function _validateHandler() private view {
        require(isHandler[msg.sender], "RewardTracker : handler validation");
    }

    /**
        Update Rewards
     */
    function _updateRewards(address _account) internal {
        uint256 blockReward = IRewardDistributor(distributor).distribute();
        
        uint256 supply = totalSupply;
        //ToDo (check) - is cumulative reward per token being updated correctly ? when we initialise _cumulativeRewardPerToken, it is initialising with value of 0 ?
        uint256 _cumulativeRewardPerToken = cumulativeRewardPerToken;
        if(supply > 0 && blockReward > 0) {
            // ToDo (check) - Perofrming operation directly since Safemath is inbuilt in solidity compiler
            _cumulativeRewardPerToken = _cumulativeRewardPerToken + (blockReward * PRECISION) / supply;
            cumulativeRewardPerToken = _cumulativeRewardPerToken;
        }
        
        //If cumulative rewards per token is 0, it means that there are no rewards yet
        if(cumulativeRewardPerToken == 0) {
            return;
        }

        if(_account != address(0)) {
            uint256 stakedAmount = stakedAmounts[_account];
            // ToDo (check) - Performing operation directly since Safemath is inbuilt in solidity compiler
            uint256 accountReward = (stakedAmount * (_cumulativeRewardPerToken - previousCumulatedRewardPerToken[_account])) / PRECISION;
            uint256 _claimableReward = claimableReward[_account] + accountReward;

            claimableReward[_account] = _claimableReward;
            previousCumulatedRewardPerToken[_account] = _cumulativeRewardPerToken;

            if(_claimableReward > 0 && stakedAmounts[_account] > 0){
                // ToDo (check) - will cumulativeRewards[_account] be initialised with value of 0?
                uint256 nextCumulativeReward = cumulativeRewards[_account] + accountReward;

                averageStakedAmounts[_account] = (averageStakedAmounts[_account] * cumulativeRewards[_account] / nextCumulativeReward) + (stakedAmount * accountReward / nextCumulativeReward);

                cumulativeRewards[_account] = nextCumulativeReward;
            }
        }
    }

    /**
        Update Vesting
     */
     function _updateVesting(address _account) private {
        uint256 amount = _getNextClaimableVestingAmount(_account);
        lastVestingTimes[_account] = block.timestamp;

        if(amount == 0) { return; }

        cumulativeVestedClaimAmounts[_account] = cumulativeVestedClaimAmounts[_account] + amount;
     }

    function _getNextClaimableVestingAmount(address _account) private view returns (uint256) {
        uint256 timeDiff = block.timestamp - lastVestingTimes[_account];

        uint256 balance = balances[_account];
        if(balance == 0) { return 0; }

        //ToDo - check again if this logic for vesting is right, for any given time, we will see how much a user is getting from vesting based on the amount of $LOGX tokens staked by the user
        uint256 claimableAmount = ( balance * timeDiff ) / vestingDuration;
        return claimableAmount;
    }
}