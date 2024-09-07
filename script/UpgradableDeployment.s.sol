// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/LogxStaker.sol";
import "../src/LogX.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";



contract UpgradableDeploymentScript is Script {
    address clearingHouse = vm.envAddress("CLEARINGHOUSE");
    address endpoint = vm.envAddress("ENDPOINT");
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_ADMIN"); 
        vm.startBroadcast(deployerPrivateKey);
        LogxStaker logXStaker = LogxStaker(vm.envAddress("STAKER_CONTRACT"));
        logXStaker.setHandler(endpoint, true);
        vm.stopBroadcast();


    }

    function deployLogXStaker(address proxyAdmin) internal {
        LogxStaker logXStaker = new LogxStaker();
        console.log("logxStaker Implementation: ", address(logXStaker));
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logXStaker),proxyAdmin,"");
        LogxStaker proxyContract = LogxStaker(payable(address(proxy)));
        console.log("logxStaker Proxy: ", address(proxyContract));
        proxyContract.initialize(0xF7122517F24C9b3c6eFbB1080Df0cF44Ef7971BA, "Staked LogX", "stLogX");

        //set CH as handler
        proxyContract.setHandler(clearingHouse, true); 
        proxyContract.setHandler(endpoint, true);

        console.log("Handler set: ", clearingHouse);
    }

    function updateLogxStakerImplementation() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_ADMIN");
        vm.startBroadcast(deployerPrivateKey); 
        LogxStaker logXStaker = new LogxStaker();
        ProxyAdmin proxyAdmin = ProxyAdmin(0x5e576B171ba6AF1a7f6326f26C1dd133937Ab5C9);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(0x60ADED80894B0dC2B7C7856d808257796f641429), address(logXStaker), "");
        vm.stopBroadcast();
    }
}