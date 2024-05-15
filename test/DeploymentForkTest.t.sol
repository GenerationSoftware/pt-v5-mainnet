// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { console2 } from "forge-std/console2.sol";

import { Test } from "forge-std/Test.sol";
import { CoreAddressBook } from "../script/DeployPrizePool.s.sol";
import { PrizePool, IERC20 } from "pt-v5-prize-pool/PrizePool.sol";
import { Claimer } from "pt-v5-claimer/Claimer.sol";
import {
    AlreadyStartedDraw,
    StaleRngRequest
} from "pt-v5-draw-manager/DrawManager.sol";

import { ILiquidationPair } from "pt-v5-liquidator-interfaces/ILiquidationPair.sol";

/// @notice Runs some basic fork tests against a deployment
contract LocalForkTest is Test {

    uint256 deployFork;

    CoreAddressBook addressBook;
    
    function setUp() public {
        deployFork = vm.createFork(vm.envString("SCRIPT_RPC_URL"));
        vm.selectFork(deployFork);

        addressBook = abi.decode(
            vm.parseBytes(
                vm.readFile(
                    string.concat("config/addressBook.txt")
                )
            ),
            (CoreAddressBook)
        );

        vm.warp(addressBook.prizePool.firstDrawOpensAt());
    }

    function testAddressBook() public view {
        assertNotEq(address(addressBook.prizePool), address(0));
        assertNotEq(address(addressBook.stakingPrizeVault), address(0));
        assertNotEq(address(addressBook.claimer), address(0));

        assertEq(addressBook.stakingPrizeVault.claimer(), address(addressBook.claimer));
        assertEq(address(addressBook.stakingPrizeVault.prizePool()), address(addressBook.prizePool));
    }

    function testClaim() public {
        // Make a deposit
        deal(addressBook.stakingPrizeVault.asset(), address(this), 1e18);
        IERC20(addressBook.stakingPrizeVault.asset()).approve(address(addressBook.stakingPrizeVault), 1e18);
        addressBook.stakingPrizeVault.deposit(1e18, address(this));

        // Make a contribution
        IERC20 prizeToken = IERC20(address(addressBook.prizePool.prizeToken()));
        deal(address(prizeToken), address(addressBook.prizePool), 1e18);
        addressBook.prizePool.contributePrizeTokens(address(addressBook.stakingPrizeVault), 1e18);

        // Award the draw
        vm.warp(addressBook.prizePool.drawClosesAt(1));
        vm.startPrank(addressBook.prizePool.drawManager());
        addressBook.prizePool.awardDraw(12345);
        vm.stopPrank();
        assertEq(addressBook.prizePool.getLastAwardedDrawId(), 1);

        // Claim prizes
        address[] memory winners = new address[](1);
        winners[0] = address(this);
        uint32[] memory winnerPrizeIndices = new uint32[](4);
        winnerPrizeIndices[0] = 0;
        winnerPrizeIndices[1] = 1;
        winnerPrizeIndices[2] = 2;
        winnerPrizeIndices[3] = 3;
        uint32[][] memory prizeIndices = new uint32[][](1);
        prizeIndices[0] = winnerPrizeIndices;

        vm.expectEmit(true, true, true, false);
        emit PrizePool.ClaimedPrize(
            address(addressBook.stakingPrizeVault),
            address(this),
            address(this),
            0,
            0,
            0,
            0,
            0,
            address(0)
        );
        Claimer(addressBook.claimer).claimPrizes(
            addressBook.stakingPrizeVault,
            addressBook.prizePool.numberOfTiers() - 3,
            winners,
            prizeIndices,
            address(this),
            0
        );
    }

    function test_rngFailure() public {
        // console2.log("1 pendingReserveContributions() ", addressBook.prizePool.pendingReserveContributions());
        // console2.log("1 reserve() ", addressBook.prizePool.reserve());
        // console2.log("1 getTotalContributedBetween(1, 1) ", addressBook.prizePool.getTotalContributedBetween(1, 1));
        // console2.log("1 getTotalContributedBetween(2, 2) ", addressBook.prizePool.getTotalContributedBetween(2, 2));

        IERC20 prizeToken = addressBook.prizePool.prizeToken();
        deal(address(prizeToken), address(this), 100e18);
        prizeToken.transfer(address(addressBook.prizePool), 100e18);
        addressBook.prizePool.contributePrizeTokens(address(addressBook.stakingPrizeVault), 100e18);

        // console2.log("2 pendingReserveContributions() ", addressBook.prizePool.pendingReserveContributions());
        // console2.log("2 reserve() ", addressBook.prizePool.reserve());
        // console2.log("2 getTotalContributedBetween(1, 1) ", addressBook.prizePool.getTotalContributedBetween(1, 1));
        // console2.log("2 getTotalContributedBetween(2, 2) ", addressBook.prizePool.getTotalContributedBetween(2, 2));

        vm.warp(addressBook.prizePool.drawClosesAt(1));
        assertTrue(addressBook.drawManager.canStartDraw(), "can start draw");
        
        vm.warp(block.timestamp + addressBook.drawManager.auctionTargetTime());
        mock_requestedAtBlock(11, block.number);
        addressBook.drawManager.startDraw(address(this), 11);

        mock_isRequestFailed(11, false);
        vm.expectRevert(abi.encodeWithSelector(AlreadyStartedDraw.selector));
        addressBook.drawManager.startDraw(address(this), 11);

        mock_isRequestFailed(11, true);
        vm.expectRevert(abi.encodeWithSelector(StaleRngRequest.selector));
        addressBook.drawManager.startDraw(address(this), 11);

        vm.warp(block.timestamp + addressBook.drawManager.auctionTargetTime());
        vm.roll(block.number + 1);
        mock_requestedAtBlock(12, block.number);
        addressBook.drawManager.startDraw(address(this), 12);

        vm.warp(block.timestamp + addressBook.drawManager.auctionTargetTime());
        mock_isRequestComplete(12, true);
        mock_randomNumber(12, 12345);
        addressBook.drawManager.finishDraw(address(this));

        // console2.log("3 pendingReserveContributions() ", addressBook.prizePool.pendingReserveContributions());
        // console2.log("3 reserve() ", addressBook.prizePool.reserve());
        // console2.log("3 getTotalContributedBetween(1, 1) ", addressBook.prizePool.getTotalContributedBetween(1, 1));
        // console2.log("3 getTotalContributedBetween(2, 2) ", addressBook.prizePool.getTotalContributedBetween(2, 2));


    }

    function mock_requestedAtBlock(uint32 requestId, uint256 blockNumber) internal {
        vm.mockCall(
            address(addressBook.standardizedRng),
            abi.encodeWithSelector(addressBook.standardizedRng.requestedAtBlock.selector, requestId),
            abi.encode(blockNumber)
        );
    }

    function mock_isRequestFailed(uint32 requestId, bool failed) internal {
        vm.mockCall(
            address(addressBook.standardizedRng),
            abi.encodeWithSelector(addressBook.standardizedRng.isRequestFailed.selector, requestId),
            abi.encode(failed)
        );
    }

    function mock_isRequestComplete(uint32 requestId, bool complete) internal {
        vm.mockCall(
            address(addressBook.standardizedRng),
            abi.encodeWithSelector(addressBook.standardizedRng.isRequestComplete.selector, requestId),
            abi.encode(complete)
        );
    }

    function mock_randomNumber(uint32 requestId, uint256 randomNumber) internal {
        vm.mockCall(
            address(addressBook.standardizedRng),
            abi.encodeWithSelector(addressBook.standardizedRng.randomNumber.selector, requestId),
            abi.encode(randomNumber)
        );
    }

}