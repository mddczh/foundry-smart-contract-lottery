// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelpConfig} from "./HelpConfig.s.sol";

contract DeplotRaffle is Script {
    function run() external {
        deployContract();
    }

    function deployContract() internal returns (Raffle, HelpConfig) {
        HelpConfig helpConfiger = new HelpConfig();
        HelpConfig.NetworkConfig memory networkConfig = helpConfiger
            .getConfig();

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subscriptionId,
            networkConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        return (raffle, helpConfiger);
    }
}
