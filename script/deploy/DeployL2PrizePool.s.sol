// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { console2 } from "forge-std/console2.sol";

import { Script } from "forge-std/Script.sol";

import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";

import { PrizePool, ConstructorParams } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";
import { ClaimerFactory } from "pt-v5-claimer/ClaimerFactory.sol";
import { LiquidationPairFactory } from "pt-v5-cgda-liquidator/LiquidationPairFactory.sol";
import { LiquidationRouter } from "pt-v5-cgda-liquidator/LiquidationRouter.sol";
import { VaultFactory } from "pt-v5-vault/VaultFactory.sol";
import { VaultBoosterFactory } from "pt-v5-vault-boost/VaultBoosterFactory.sol";

import { RemoteOwner } from "remote-owner/RemoteOwner.sol";
import { RngRelayAuction } from "pt-v5-draw-auction/RngRelayAuction.sol";

import { ScriptHelpers } from "../helpers/ScriptHelpers.sol";

contract DeployL2PrizePool is ScriptHelpers {
  function run() public {
    vm.startBroadcast();

    IERC20 prizeToken = IERC20(_getToken("POOL"));

    // TODO: which period offset should we use?
    TwabController twabController = new TwabController(TWAB_PERIOD_LENGTH, _getAuctionOffset());

    console2.log("constructing prize pool....");

    PrizePool prizePool = new PrizePool(
      ConstructorParams({
        prizeToken: prizeToken,
        twabController: twabController,
        drawPeriodSeconds: DRAW_PERIOD_SECONDS,
        firstDrawStartsAt: _getFirstDrawStartsAt(),
        smoothing: _getContributionsSmoothing(),
        grandPrizePeriodDraws: GRAND_PRIZE_PERIOD_DRAWS,
        numberOfTiers: MIN_NUMBER_OF_TIERS,
        tierShares: TIER_SHARES,
        reserveShares: RESERVE_SHARES
      })
    );

    console2.log("constructing auction....");

    RemoteOwner remoteOwner = new RemoteOwner(
      ETHEREUM_CHAIN_ID,
      ERC5164_EXECUTOR_OPTIMISM,
      address(_getL1RngAuctionRelayerRemote())
    );

    RngRelayAuction rngRelayAuction = new RngRelayAuction(
      prizePool,
      address(remoteOwner),
      AUCTION_DURATION,
      AUCTION_TARGET_SALE_TIME,
      AUCTION_MAX_REWARD
    );

    prizePool.setDrawManager(address(rngRelayAuction));

    ClaimerFactory claimerFactory = new ClaimerFactory();
    claimerFactory.createClaimer(
      prizePool,
      CLAIMER_MIN_FEE,
      CLAIMER_MAX_FEE,
      _getClaimerTimeToReachMaxFee(),
      _getClaimerMaxFeePortionOfPrize()
    );

    LiquidationPairFactory liquidationPairFactory = new LiquidationPairFactory();
    new LiquidationRouter(liquidationPairFactory);

    new VaultFactory();
    new VaultBoosterFactory();

    vm.stopBroadcast();
  }
}
