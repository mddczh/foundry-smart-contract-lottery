// SPDX-License-Indetifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract CodeConstants {
    uint256 public constant ETH_SPEOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    /* VRF 模拟参数 */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;
}

contract HelpConfig is CodeConstants, Script {
    error HelpConfig__NoConfigForChainId(uint256 chainId);

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
    }

    NetworkConfig internal localNetworkConfig;

    mapping(uint256 chainId => NetworkConfig) internal networkConfigs;

    constructor() {
        networkConfigs[ETH_SPEOLIA_CHAIN_ID] = getEthSepoliaConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) internal returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelpConfig__NoConfigForChainId(chainId);
        }
    }

    function getConfig() external returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getEthSepoliaConfig()
        internal
        pure
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionId: 0,
                callbackGasLimit: 500000
            });
    }

    function getOrCreateAnvilConfig() internal returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();

        VRFCoordinatorV2_5Mock vrfcoordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UNIT_LINK
        );

        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfcoordinator),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // 本地网络 gaslane 不重要
            subscriptionId: 0,
            callbackGasLimit: 500000
        });

        return localNetworkConfig;
    }
}
