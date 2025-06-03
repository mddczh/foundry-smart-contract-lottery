// 1️⃣ 版本声明
// 2️⃣ 依赖导入（Imports）
// 3️⃣ 事件（Events）
// 3️⃣ 自定义错误（Errors）
// 4️⃣ 接口、库、合约（Interfaces, Libraries, Contracts）

// 🔽 合约内部布局 🔽
// 1️⃣ 类型声明（Type declarations）
// 2️⃣ 状态变量（State variables）
// 3️⃣ 事件（Events）
// 4️⃣ 自定义错误（Errors）
// 5️⃣ 修饰符（Modifiers）
// 6️⃣ 函数（Functions）

// 🔽 函数的推荐排序 🔽
// 1️⃣ 构造函数（constructor）
// 2️⃣ receive() 函数（如果存在）
// 3️⃣ fallback() 函数（如果存在）
// 4️⃣ external 函数
// 5️⃣ public 函数
// 6️⃣ internal 函数
// 7️⃣ private 函数
// 8️⃣ 视图（view） & 纯函数（pure）

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from
    "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title 一个抽奖合约示例
 * @author cyc
 * @notice 本合约用于创建一个彩票智能合约
 * @dev 本合约实现了 Chinklink VRF 随机数生成器，Chinklink Automation 定时器
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    // Chainlink VRF 相关变量
    bytes32 private immutable i_gasLane;
    uint256 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    bool private constant ENABLE_NATIVE_PAYMENT = false;

    // Raffle 相关变量
    uint256 private immutable i_entranceFee;
    // 抽奖持续时间
    uint256 private immutable i_interval;
    address payable[] private s_players;
    // 记录抽奖开始时间
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    event Raffle__EnterRaffle(address indexed player);
    event Raffle__PickedWinner(address winner);
    event Raffle__RequestedRaffleWinner(uint256 indexed requestId);
    event Raffle__WinnerCannotReceiveETH(address indexed winner, uint256 amount);

    error Raffle__NotEnoughETHSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_interval = interval;
        i_entranceFee = entranceFee;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;

        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() external payable {
        // require(msg.sender >= i_entranceFee, "Not enough ETH!");
        if (msg.value < i_entranceFee) revert Raffle__NotEnoughETHSent();
        if (s_raffleState != RaffleState.OPEN) revert Raffle__RaffleNotOpen();
        s_players.push(payable(msg.sender));
        // emit event
        emit Raffle__EnterRaffle(msg.sender);
    }

    // 向 VFR 请求随机数，符合条件后封装 VRFV2PlusClient.RandomWordsRequest，请求随机数
    function performUpkeep(bytes calldata /* performData */ ) external override {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: ENABLE_NATIVE_PAYMENT}))
            })
        );

        emit Raffle__RequestedRaffleWinner(requestId);
    }

    /**
     * @dev 该函数由 Chainlink Keeper 节点调用，
     * 它会检查 `upkeepNeeded` 是否返回 true。
     * 需要满足以下条件之一才能返回 true：
     * 1. 抽奖的时间间隔已过去 ⏳。
     * 2. 抽奖仍然开放 🎟️。
     * 3. 合约有 ETH 💰。
     * 4. 至少有一位参与者 🏃‍♂️。
     * 5. 你的订阅中有足够的 LINK 资金 🔗。
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
        return (upkeepNeeded, "0x0");
    }

    // VRF 回调函数，对随机数的处理操作
    function fulfillRandomWords(
        uint256,
        /*requestId*/
        uint256[] calldata randomWords
    ) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winnerIndex];

        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        emit Raffle__PickedWinner(winner);

        // 发送奖金
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success) {
            // 用于测试
            emit Raffle__WinnerCannotReceiveETH(winner, address(this).balance);
            // 发送失败，抛出异常
            revert Raffle__TransferFailed();
        }
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers() external view returns (address payable[] memory) {
        return s_players;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
