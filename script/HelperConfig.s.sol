// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {console} from "forge-std/console.sol";

abstract contract CodeConstants {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    /* VRF 模拟参数 */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;
}

/**
 * @title HelperConfig
 * @author cyc
 * @notice 本合约用于获取不同网络的配置参数
 * @dev 本合约实现了 Chainlink VRF 和 Automation 的配置参数
 */
contract HelperConfig is CodeConstants, Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address linkToken;
        address account;
    }

    NetworkConfig internal localNetworkConfig;

    mapping(uint256 chainId => NetworkConfig) internal networkConfigs;

    error HelperConfig__NoConfigForChainId(uint256 chainId);

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
    }

    /**
     * @notice 获取当前网络的配置参数
     * @return NetworkConfig 当前网络的配置参数
     */
    /// @dev 如果当前网络是本地网络，则创建一个新的配置参数
    /// @dev 如果当前网络是测试网络，则返回测试网络的配置参数
    function getConfig() external returns (NetworkConfig memory) {
        if (networkConfigs[block.chainid].vrfCoordinator != address(0)) {
            return networkConfigs[block.chainid];
        } else if (block.chainid == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__NoConfigForChainId(block.chainid);
        }
    }

    /**
     * @notice 获取以太坊 Sepolia 测试网络的配置参数
     * @return NetworkConfig 以太坊 Sepolia 测试网络的配置参数
     */
    function getEthSepoliaConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 22556376891597629229536621055545287048965084039999932745646553582846786916532, // sepolia 上创建的真实的订阅 id
            callbackGasLimit: 500000,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0xb574cd981DCBd14f94f5E3bdaE35c38F3cAb08db
        });
    }

    /**
     * @notice 获取本地网络的配置参数
     * @return NetworkConfig 本地网络的配置参数
     */
    /// @dev 如果本地网络的配置参数已经存在，则返回该配置参数
    /// @dev 如果本地网络的配置参数不存在，则创建一个新的配置参数
    /// @dev 创建一个新的 VRFCoordinatorV2_5Mock 和 LinkToken
    function getOrCreateAnvilConfig() internal returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();

        VRFCoordinatorV2_5Mock vrfcoordinator =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);

        LinkToken linkToken = new LinkToken();

        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfcoordinator),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // 本地网络 gaslane 不重要
            subscriptionId: 0,
            callbackGasLimit: 500000,
            linkToken: address(linkToken),
            // account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
            account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        });

        return localNetworkConfig;
    }
}
