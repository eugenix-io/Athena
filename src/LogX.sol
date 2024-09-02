// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
    @title $LogX
 */

import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "./interfaces/ILogX.sol";
import "./common/Errors.sol";

contract LogX is IERC20, ILogX {
    using SafeERC20 for IERC20;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    //ToDo - add a limit of 1 billion tokens on total supply
    uint256 public override totalSupply;
    uint256 public maxSupply = 1_000_000_000 * 1e18; // 1 billion tokens
    
    address public gov;

    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowances;
    mapping (address => bool) public override isMinter;

    modifier onlyGov() {
        require(msg.sender == gov, "LogX: forbidden");
        _;
    }

    modifier onlyMinter() {
        require(isMinter[msg.sender], "LogX: forbidden");
        _;
    }

    constructor(uint256 _initialSupply) {
        name = "LOGX";
        symbol = "$LOGX";
        gov = msg.sender;
        _mint(msg.sender, _initialSupply);
    }

    function setGov(address _gov) external onlyGov {
        require(_gov != address(0), "LogX: invalid address");
        gov = _gov;
    }

    function setInfo(string memory _name, string memory _symbol) external override onlyGov {
        name = _name;
        symbol = _symbol;
    }

    function setMinter(address _minter, bool _isActive) external override onlyGov {
        require(_minter != address(0), "LogX: invalid address");
        isMinter[_minter] = _isActive;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external override onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function id() external view returns (string memory) {
        return symbol;
    }

    function balanceOf(address _account) external view override returns (uint256) {
        return balances[_account];
    }

    function transfer(address _recipient, uint256 _amount) external override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) external view override returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) external override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) external override returns (bool) {
        uint256 allowanceAmount = allowances[_sender][msg.sender];
        require(allowanceAmount >= _amount, ERR_TRANSFER_AMOUNT_EXCEEDS_ALLOWANCE);
        uint256 nextAllowance = allowances[_sender][msg.sender] - _amount;
        _approve(_sender, msg.sender, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function mint(address _account, uint256 _amount) external override onlyMinter {
        require(totalSupply + _amount <= maxSupply, ERR_MINT_AMOUNT_EXCEEDS_MAX_SUPPLY);
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external override onlyMinter {
        _burn(_account, _amount);
    }

    function _mint(address _account, uint256 _amount) internal {
        require(_account != address(0), "LogX: mint to the zero address");

        totalSupply = totalSupply + _amount;
        balances[_account] = balances[_account] + _amount;

        emit Transfer(address(0), _account, _amount);
    }

    function _burn(address _account, uint256 _amount) internal {
        require(_account != address(0), "LogX: burn from the zero address");
        require(balances[_account] >= _amount, ERR_BURN_AMOUNT_EXCEEDS_BALANCE);
        balances[_account] = balances[_account] - _amount;
        totalSupply = totalSupply - _amount;

        emit Transfer(_account, address(0), _amount);
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        require(_sender != address(0), ERR_TRANSFER_FROM_ZERO_ADDRESS);
        require(_recipient != address(0), ERR_TRANSFER_TO_ZERO_ADDRESS);
        //Note - since $LOGX will be used as gas token on Orbit chain, transfering the token to self should not be allowed.
        require(_sender != _recipient, "LogX: transfer to self");
        require(balances[_sender] >= _amount, ERR_TRANSFER_AMOUNT_EXCEEDS_BALANCE);

        balances[_sender] = balances[_sender] - _amount;
        balances[_recipient] = balances[_recipient] + _amount;

        emit Transfer(_sender, _recipient,_amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), ERR_APPROVE_FROM_ZERO_ADDRESS);
        require(_spender != address(0), ERR_APPROVE_TO_ZERO_ADDRESS);

        allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }
}
