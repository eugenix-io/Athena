// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/LogxStaker.sol";
import "../src/LogX.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";



contract UpgradableDeploymentScript is Script {
    address clearingHouse = vm.envAddress("CLEARINGHOUSE");
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_ADMIN"); 
        vm.startBroadcast(deployerPrivateKey);
        // ProxyAdmin proxyAdmin = ProxyAdmin(0x5e576B171ba6AF1a7f6326f26C1dd133937Ab5C9);
        // console.log("Proxy Admin: ", address(proxyAdmin));
        // address stakerProxy = deployLogXStaker(address(proxyAdmin));
        // console.log("Staker Proxy: ", stakerProxy);
        deployLogXStaker(0xE5d5aC6988be36e5B4e5A4D539cFA9a1790C94f0);
        vm.stopBroadcast();


    }

    function deployLogXStaker(address proxyAdmin) internal returns(address) {
        LogxStaker logXStaker = new LogxStaker();
        console.log("logxStaker Implementation: ", address(logXStaker));
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logXStaker),proxyAdmin,"");
        LogxStaker proxyContract = LogxStaker(payable(address(proxy)));
        console.log("Proxy Address: ", address(proxy));
        proxyContract.initialize("Staked LogX","stLogX");

        //set CH as handler
        proxyContract.setHandler(clearingHouse, true); 

        console.log("Handler set: ", clearingHouse);
        return address(proxy);
    }

    function updateLogxStakerImplementation() internal returns(address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_ADMIN");
        vm.startBroadcast(deployerPrivateKey); 
        LogxStaker logXStaker = new LogxStaker();
        ProxyAdmin proxyAdmin = ProxyAdmin(0x5e576B171ba6AF1a7f6326f26C1dd133937Ab5C9);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(0x60ADED80894B0dC2B7C7856d808257796f641429), address(logXStaker), "");
        vm.stopBroadcast();

    }
}