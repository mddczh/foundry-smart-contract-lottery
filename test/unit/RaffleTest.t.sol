// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is CodeConstants, Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    address account;

    address public PLAYER = makeAddr("player");
    uint256 public constant PLAYER_STARTING_BALANCE = 10 ether;

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + interval + 1);
        _;
    }

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();

        vm.deal(PLAYER, PLAYER_STARTING_BALANCE);
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        account = config.account;
    }

    function testRaffleInitializesIsOpenState() external view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*######################################################################
    #                           🎁EnterRaffle🎁                           #
    ######################################################################*/

    function testRaffleRevertsWhenNotEnoughETHSent() external {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughETHSent.selector);
        raffle.enterRaffle{value: 0.00001 ether}();
    }

    function testRaffleRecordsPlayersWhenEnter() external {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address payable[] memory players = raffle.getPlayers();
        assertEq(players[0], PLAYER);
    }

    function testEnteringRaffleEmitsEvent() external {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.Raffle__EnterRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() external raffleEntered {
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*######################################################################
    #                           🎟️CheckUpkeep🎟️                           #
    ######################################################################*/

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() external {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + interval + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() external raffleEntered {
        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() external {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + interval);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() external raffleEntered {
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    /*######################################################################
    #                          💰PerformUpkeep💰                          #
    ######################################################################*/

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() external raffleEntered {
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() external {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + interval);
        uint256 currentBalance = address(raffle).balance;
        uint256 playerNum = 1;
        Raffle.RaffleState raffleState = Raffle.RaffleState.OPEN;

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, playerNum, raffleState)
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() external raffleEntered {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        assert(requestId > 0);
        assert(raffleState == Raffle.RaffleState.CALCULATING);
    }

    /*######################################################################
    #                       🚀FulfillRandomWords🚀                        #
    ######################################################################*/

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    /**
     * @dev fuzzing test
     * @param requestId fuzzing requestId
     */
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 requestId)
        external
        raffleEntered
        skipFork
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerAndSendsMoney() external raffleEntered skipFork {
        // arrange
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, PLAYER_STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimestamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimestamp = raffle.getLastTimeStamp();
        uint256 price = entranceFee * (additionalEntrants + 1);
        uint256 numOfPlayers = raffle.getPlayers().length;

        assertEq(recentWinner, expectedWinner);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assertEq(winnerBalance, winnerStartingBalance + price);
        assert(endingTimestamp > startingTimestamp);
        assertEq(numOfPlayers, 0);
    }

    function testFulfillRandomWordsRevertIfWinnerCannotReceiveETH() external skipFork {
        // arrange
        entranceFee = raffle.getEntranceFee();

        vm.startBroadcast();
        MaliciousWinner maliciousWinner = new MaliciousWinner();
        vm.stopBroadcast();

        hoax(address(maliciousWinner), PLAYER_STARTING_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + interval + 1);

        // act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        vm.expectEmit(true, false, false, true);
        emit Raffle.Raffle__WinnerCannotReceiveETH(address(maliciousWinner), address(raffle).balance);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
    }
}

// 恶意合约，拒绝接收ETH
contract MaliciousWinner {
    error MaliciousWinner__IDontReceiveETH();
    // fallback和receive都revert，任何ETH转账都会失败

    receive() external payable {
        revert MaliciousWinner__IDontReceiveETH();
    }

    fallback() external payable {
        revert MaliciousWinner__IDontReceiveETH();
    }
}
