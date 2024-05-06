// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
 * @title ILogX Interface
 * @dev Interface for the LogX token contract functionalities beyond standard ERC20
 */
interface ILogX {
    /**
     * @dev Sets a new governance address. Only callable by the current governance address.
     * @param _gov New governance address.
     */
    function setGov(address _gov) external;

    /**
     * @dev Sets the token information such as name and symbol. Only callable by the governance address.
     * @param _name New token name.
     * @param _symbol New token symbol.
     */
    function setInfo(string memory _name, string memory _symbol) external;

    /**
     * @dev Sets or unsets an address as a minter. Only callable by the governance address.
     * @param _minter The address to modify minter status.
     * @param _isActive Whether the address should be a minter or not.
     */
    function setMinter(address _minter, bool _isActive) external;

    /**
     * @dev Allows the governance to withdraw any ERC20 token sent to the contract by mistake.
     * @param _token The address of the token to withdraw.
     * @param _account The destination address of the tokens.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdrawToken(address _token, address _account, uint256 _amount) external;

    /**
     * @dev Mint new tokens to a specified address. This can only be called by authorized minters.
     * @param _account The address to mint tokens to.
     * @param _amount The amount of tokens to mint.
     */
    function mint(address _account, uint256 _amount) external;

    /**
     * @dev Burn tokens from a specified address. This can only be called by authorized minters.
     * @param _account The address from which tokens will be burned.
     * @param _amount The amount of tokens to burn.
     */
    function burn(address _account, uint256 _amount) external;

    /**
     * @dev Check if an address is authorized to mint new tokens.
     * @param _account The address to verify.
     * @return A boolean indicating if the address is authorized to mint tokens.
     */
    function isMinter(address _account) external view returns (bool);
}
