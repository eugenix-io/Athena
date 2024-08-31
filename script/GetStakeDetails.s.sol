// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/LogxStaker.sol";
import "../src/LogX.sol";

contract GetStakerDetails is Script {
    LogxStaker logxStaker =
        LogxStaker(payable(0xd9f398f3B4fe819B2811cCd65C9a31a13427028a));

    function run() external view {
        bytes32 stake_id = 0x6cf15f1c9fa7da9f62e08b3828761aaffdb4db1dc5ae6e71167fbd331e677c27;
        bytes32 subaccount = 0x0000000000016d1cb5da5f00cd3c9aef83a30222e65bea2aa2c3000000000001;

        (
            bytes32 account,
            uint256 amount,
            uint256 duration,
            uint256 apy,
            uint256 startTime
        ) = logxStaker.stakes(
                stake_id
            );
        console.logBytes32(account);
        console.log("Amount: ", amount);
        console.log("Duration: ", duration);
        console.log("APY: ", apy);
        console.log("Start Time: ", startTime);

        bytes32[] memory ids = logxStaker.getUserIds(
            subaccount
        );

        for (uint256 i = 0; i < ids.length; i++) {
            console.logBytes32(ids[i]);
        }

        uint256 claimableRewards = logxStaker.getStakeIdRewards(
            stake_id,
            block.timestamp
        );

        console.log("Claimable Rewards: ", claimableRewards);
    }
}
