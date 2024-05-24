// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/LogxStaker.sol";
import "../src/LogX.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";



contract UpgradableDeploymentScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_ADMIN"); 
        vm.startBroadcast(deployerPrivateKey);
        ProxyAdmin proxyAdmin = new ProxyAdmin(0x143328D5d7C84515b3c8b3f8891471ff872C0015);
        console.log("Proxy Admin: ", address(proxyAdmin));
        address stakerProxy = deployLogXStaker(address(proxyAdmin));
        console.log("Staker Proxy: ", stakerProxy);
        vm.stopBroadcast();


    }

    function deployLogXStaker(address proxyAdmin) internal returns(address) {
        LogxStaker logXStaker = new LogxStaker();
        console.log("logxStaker Implementation: ", address(logXStaker));
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logXStaker),proxyAdmin,"");
        LogxStaker proxyContract = LogxStaker(payable(address(proxy)));
        proxyContract.initialize("Staked LogX","stLogX");
        return address(proxy);

    }

    function updateLogxStakerImplementation() external returns(address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_ADMIN");
        vm.startBroadcast(deployerPrivateKey); 
        LogxStaker logXStaker = new LogxStaker();
        ProxyAdmin proxyAdmin = ProxyAdmin(0x0196b5B8ADB204e7E4608a118f06c3aF46495663);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(0xbA9eCCaB638CCBf58f0065F8C1E5483a6733B6D9), address(logXStaker), "");
        vm.stopBroadcast();

    }
}