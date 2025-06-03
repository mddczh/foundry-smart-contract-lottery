// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract CreateSubscription is Script, CodeConstants {
    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        uint256 subscriptionId = createSubscription(config.vrfCoordinator);
        return (subscriptionId, config.vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256) {
        console.log("Creating subscription on chain Id...: ", block.chainid);

        // @audit-ok anvil/sepolia 测试成功
        vm.startBroadcast();
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your subscription ID is: ", subscriptionId);
        console.log("Please update subscription ID in your HelperConfig.s.sol. ");

        return subscriptionId;
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 private constant FUND_AMOUNT = 3 ether; // = 3 LINK

    function run() external {
        fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        fundSubscription(config.vrfCoordinator, config.subscriptionId, config.linkToken);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken) public {
        console.log("Funding subscription...: ", subscriptionId);
        console.log("Using vrfCoordinator...: ", vrfCoordinator);
        console.log("On chainid...: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            // @audit-ok sepolia 测试成功
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }

        console.log("Subscription funded!");
    }
}

contract AddConsumer is Script {
    address private constant CONSUMER = 0x7655e291D412220Bb143096cce3983C5BcC1D1e4;

    function run() external {
        addConsumerUsingConfig();
    }

    function addConsumerUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        addConsumer(config.vrfCoordinator, config.subscriptionId, CONSUMER);
    }

    function addConsumer(address vrfCoordinator, uint256 subscriptionId, address consumer) public {
        console.log("Adding consumer for subscription Id...: ", subscriptionId);

        vm.startBroadcast();
        // @audit-ok anvil/sepolia 测试成功
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, consumer);
        vm.stopBroadcast();
    }
}
