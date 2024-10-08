// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/LogX.sol";  // Adjust the path as necessary to point to your LogX contract.

contract DeployLogX is Script {
    function run() external {
        vm.startBroadcast();

        // Set the initial supply as per your requirement, e.g., 100,000 LOGX tokens.
        uint256 initialSupply = 50000 * 1e18; // Using 1e18 to adhere to the 18 decimals in ERC-20

        // Deploy the contract
        LogX logx = new LogX(initialSupply);

        // Optionally, you can set up additional configuration here, such as setting a government address or minters.
        // logx.setGov(<address>);
        // logx.setMinter(<address>, true);

        vm.stopBroadcast();
    }
}

//Command to Deploy LogX Token - 
//forge script DeployLogX --broadcast --rpc-url $RPC_URL --private-key $PRIVATE_KEY

//Command to call setInfo() function - 
// calldata "setInfo(string,string)" "$LogX" "LogX"
// cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $CONTRACT_ADDRESS "CALL_DATA"

//Command to call setMinter() function -
// cast calldata "setMinter(address,bool)" 0x9C5Dea4101fc7600bB2E363F368Ee8EED638fC97 true
// cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $CONTRACT_ADDRESS "CALL_DATA"

//Command to check if a given address has minting access - 
// cast call $CONTRACT_ADDRESS "isMinter(address)" $ADDRESS --rpc-url $RPC_URL

//Command to mint tokens from a minter addresss -
// cast calldata "mint(address,uint256)" $RECEIVER_ADDRESS $MINT_AMOUNT (10^18)
// cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $CONTRACT_ADDRESS "CALL_DATA"