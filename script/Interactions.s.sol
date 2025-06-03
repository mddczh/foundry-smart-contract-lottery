// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script, CodeConstants {
    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        uint256 subscriptionId = createSubscription(config.vrfCoordinator, config.account);
        return (subscriptionId, config.vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator, address account) public returns (uint256) {
        console.log("Creating subscription on chainid: ", block.chainid);

        // @audit-ok anvil/sepolia 测试成功
        vm.startBroadcast(account);
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your subscription ID is: ", subscriptionId);
        console.log("Please update subscription ID in your HelperConfig.s.sol. ");

        return subscriptionId;
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 private constant FUND_AMOUNT = 3 ether; // = 3 LINK

    function run() external returns (uint256, address) {
        return fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription create = new CreateSubscription();
            (uint256 subscriptionId, address vrfCoordinator) = create.run();
            config.subscriptionId = subscriptionId;
            config.vrfCoordinator = vrfCoordinator;
        }
        fundSubscription(config.vrfCoordinator, config.subscriptionId, config.linkToken, config.account);

        return (config.subscriptionId, config.vrfCoordinator);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account)
        public
    {
        console.log("Funding subscription: ", subscriptionId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On chainid: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT * 100);
            vm.stopBroadcast();
        } else {
            // @audit-ok sepolia 测试成功
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }

        console.log("Subscription funded!");
    }
}

contract AddConsumer is Script {
    // address private constant CONSUMER = 0x7655e291D412220Bb143096cce3983C5BcC1D1e4;

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);

        addConsumerUsingConfig(raffle);
    }

    function addConsumerUsingConfig(address consumer) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            FundSubscription fund = new FundSubscription();
            (uint256 subscriptionId, address vrfCoordinator) = fund.run();

            config.subscriptionId = subscriptionId;
            config.vrfCoordinator = vrfCoordinator;
        }

        addConsumer(config.vrfCoordinator, config.subscriptionId, consumer, config.account);
    }

    function addConsumer(address vrfCoordinator, uint256 subscriptionId, address consumer, address account) public {
        console.log("Adding consumer contract: ", consumer);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On chainid: ", block.chainid);

        vm.startBroadcast(account);
        // @audit-ok anvil/sepolia 测试成功
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, consumer);
        vm.stopBroadcast();
    }
}
