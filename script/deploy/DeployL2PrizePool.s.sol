// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/console2.sol";

import { Script } from "forge-std/Script.sol";

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";

import { PrizePool, ConstructorParams } from "pt-v5-prize-pool/PrizePool.sol";
import { sd1x18 } from "prb-math/SD1x18.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";
import { Claimer } from "pt-v5-claimer/Claimer.sol";
import { LiquidationPairFactory } from "pt-v5-cgda-liquidator/LiquidationPairFactory.sol";
import { LiquidationRouter } from "pt-v5-cgda-liquidator/LiquidationRouter.sol";
import { VaultFactory } from "pt-v5-vault/VaultFactory.sol";

import { RemoteOwner } from "remote-owner/RemoteOwner.sol";
import { RngRelayAuction } from "pt-v5-draw-auction/RngRelayAuction.sol";

import { ScriptHelpers } from "../helpers/ScriptHelpers.sol";

contract DeployL2PrizePool is ScriptHelpers {
  function run() public {
    vm.startBroadcast();

    ERC20 prizeToken = ERC20(_getToken("POOL"));
    TwabController twabController = new TwabController(TWAB_PERIOD_LENGTH, _auctionOffset());

    console2.log("constructing prize pool....");

    PrizePool prizePool = new PrizePool(
      ConstructorParams(
        prizeToken,
        twabController,
        address(0),
        DRAW_PERIOD_SECONDS,
        _firstDrawStartsAt(), // drawStartedAt
        sd1x18(0.3e18), // alpha
        GRAND_PRIZE_PERIOD_DRAWS,
        uint8(3), // minimum number of tiers
        TIER_SHARES,
        RESERVE_SHARES
      )
    );

    console2.log("constructing auction....");

    RemoteOwner remoteOwner = new RemoteOwner(
      5,
      ERC5164_EXECUTOR_OPTIMISM,
      address(_getL1RngAuctionRelayerRemote())
    );

    RngRelayAuction rngRelayAuction = new RngRelayAuction(
      prizePool,
      address(remoteOwner),
      AUCTION_DURATION,
      AUCTION_TARGET_SALE_TIME
    );

    prizePool.setDrawManager(address(rngRelayAuction));

    new Claimer(
      prizePool,
      CLAIMER_MIN_FEE,
      CLAIMER_MAX_FEE,
      DRAW_PERIOD_SECONDS,
      CLAIMER_MAX_FEE_PERCENT()
    );

    LiquidationPairFactory liquidationPairFactory = new LiquidationPairFactory();
    new LiquidationRouter(liquidationPairFactory);

    new VaultFactory();

    vm.stopBroadcast();
  }
}
