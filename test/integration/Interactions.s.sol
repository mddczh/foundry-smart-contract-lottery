// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

/*######################################################################
#                           🌈DeployRaffle🌈                          #
######################################################################*/

contract TestDeployRaffle is Test {
    Raffle raffle;
    DeployRaffle deployRaffle;
    HelperConfig helperConfig;

    function setUp() external {
        deployRaffle = new DeployRaffle();
    }

    function testRunCanDeoloyRaffleAndHelperConfig() external {
        (raffle, helperConfig) = deployRaffle.run();

        assert(address(raffle) != address(0));
        assert(address(helperConfig) != address(0));
    }
}

/*######################################################################
#                           💸HelperConfig💸                           #
######################################################################*/

contract TestHelperConfig is Test, CodeConstants {
    HelperConfig helperConfig;

    function setUp() external {
        helperConfig = new HelperConfig();
    }

    function testGetConfigCanReturnNetworkConfigsWhenVrfCoordinatorIsnotNone() external {
        vm.chainId(ETH_SEPOLIA_CHAIN_ID);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        assertEq(config.account, 0xb574cd981DCBd14f94f5E3bdaE35c38F3cAb08db);
    }

    function testGetConfigCanReturnAnvilConfigWhenChainIdIsLocal() external {
        vm.chainId(LOCAL_CHAIN_ID);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        assertEq(config.account, 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
    }

    function testGetConfigRevertsWhenNoConfigForChainId() external {
        uint256 invalidChainId = 99999999; // An invalid chain ID
        vm.chainId(invalidChainId); // An invalid chain ID

        vm.expectRevert(abi.encodeWithSelector(HelperConfig.HelperConfig__NoConfigForChainId.selector, invalidChainId));

        helperConfig.getConfig();
    }
}

/*/////////////////////////////////////////////////////////////////////
                            Interactions                           
/////////////////////////////////////////////////////////////////////*/

contract TestInteractions is Test, CodeConstants {
    CreateSubscription createSubscription;
    FundSubscription fundSubscription;
    AddConsumer addConsumer;

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    modifier skipLocal() {
        if (block.chainid == LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function setUp() external {
        createSubscription = new CreateSubscription();
        fundSubscription = new FundSubscription();
        addConsumer = new AddConsumer();
    }

    function testCreateSubscription() external {
        (uint256 subscriptionId,) = createSubscription.createSubscriptionUsingConfig();

        assert(subscriptionId > 0);
    }

    function testFundSubscription() external {
        fundSubscription.fundSubscriptionUsingConfig();

        // We can't assert anything here, just check if it runs without reverting
    }

    function testAddConsumer() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (Raffle raffle,) = deployRaffle.deployContract();
        addConsumer.addConsumerUsingConfig(address(raffle));

        // We can't assert anything here, just check if it runs without reverting
    }

    function testAddConsumerCanGetMostRecentDeployment() external skipFork {
        addConsumer.run();
    }

    function testLocalFundSubscription() external skipFork {
        fundSubscription.run();
    }

    function testSepoliaFundSubscription() external skipLocal {
        fundSubscription.run();
    }
}
