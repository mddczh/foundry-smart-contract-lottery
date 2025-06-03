// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

/**
 * @title
 * @author
 * @notice 在 127.0.0.1:8545 上部署 Raffle 合约时，由于 CreateSubscription 时
 * subId = uint256(keccak256(abi.encodePacked(msg.sender, blockhash(block.number - 1), address(this), currentSubNonce)));
 * 在开启 anvil 时需要配置区块每过几秒自动滚动 anvil --block-time 10，否则 block.number - 1 会导致下溢错误
 */
contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        return deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // If the subscriptionId is 0, create a new subscription
        // and fund it with LINK tokens
        if (config.subscriptionId == 0) {
            CreateSubscription create = new CreateSubscription();
            config.subscriptionId = create.createSubscription(config.vrfCoordinator, config.account);

            FundSubscription fund = new FundSubscription();
            fund.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.linkToken, config.account);
        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        console.log("Raffle contract deployed to: ", address(raffle));

        // Add consumer to subscription
        AddConsumer add = new AddConsumer();
        add.addConsumer(config.vrfCoordinator, config.subscriptionId, address(raffle), config.account);

        return (raffle, helperConfig);
    }
}
