// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/console2.sol";

import { Script } from "forge-std/Script.sol";

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { ud2x18 } from "prb-math/UD2x18.sol";
import { sd1x18 } from "prb-math/SD1x18.sol";

import { ChainlinkVRFV2Direct } from "pt-v5-chainlink-vrf-v2-direct/ChainlinkVRFV2Direct.sol";
import { ChainlinkVRFV2DirectRngAuctionHelper } from "pt-v5-chainlink-vrf-v2-direct/ChainlinkVRFV2DirectRngAuctionHelper.sol";
import { IRngAuction } from "pt-v5-chainlink-vrf-v2-direct/interfaces/IRngAuction.sol";
import { ClaimerFactory } from "pt-v5-claimer/ClaimerFactory.sol";
import { ILiquidationSource } from "pt-v5-liquidator-interfaces/ILiquidationSource.sol";
import { LiquidationPair } from "pt-v5-cgda-liquidator/LiquidationPair.sol";
import { LiquidationPairFactory } from "pt-v5-cgda-liquidator/LiquidationPairFactory.sol";
import { RngAuction } from "pt-v5-draw-auction/RngAuction.sol";
import { RngAuctionRelayerDirect } from "pt-v5-draw-auction/RngAuctionRelayerDirect.sol";
import { RngRelayAuction } from "pt-v5-draw-auction/RngRelayAuction.sol";
import { LiquidationRouter } from "pt-v5-cgda-liquidator/LiquidationRouter.sol";
import { PrizePool, ConstructorParams, SD59x18 } from "pt-v5-prize-pool/PrizePool.sol";
import { RNGInterface } from "rng/RNGInterface.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";
import { VaultFactory } from "pt-v5-vault/VaultFactory.sol";

import { ScriptHelpers } from "../helpers/ScriptHelpers.sol";

contract DeployPool is ScriptHelpers {
  function run() public {
    vm.startBroadcast();

    ERC20 prizeToken = ERC20(_getToken("POOL"));

    // TODO: which period offset should we use?
    TwabController twabController = new TwabController(TWAB_PERIOD_LENGTH, _getAuctionOffset());

    console2.log("constructing rng stuff....");

    ChainlinkVRFV2Direct chainlinkRng = new ChainlinkVRFV2Direct(
      EXECUTIVE_TEAM_ETHEREUM_ADDRESS,
      _getVrfV2Wrapper(),
      CHAINLINK_CALLBACK_GAS_LIMIT,
      CHAINLINK_REQUEST_CONFIRMATIONS
    );

    RngAuction rngAuction = new RngAuction(
      RNGInterface(chainlinkRng),
      EXECUTIVE_TEAM_ETHEREUM_ADDRESS,
      DRAW_PERIOD_SECONDS,
      _getAuctionOffset(),
      AUCTION_DURATION,
      AUCTION_TARGET_SALE_TIME,
      FIRST_AUCTION_TARGET_REWARD_FRACTION
    );

    RngAuctionRelayerDirect rngAuctionRelayerDirect = new RngAuctionRelayerDirect(rngAuction);

    new ChainlinkVRFV2DirectRngAuctionHelper(chainlinkRng, IRngAuction(address(rngAuction)));

    console2.log("constructing prize pool....");

    PrizePool prizePool = new PrizePool(
      ConstructorParams({
        prizeToken: prizeToken,
        twabController: twabController,
        drawPeriodSeconds: DRAW_PERIOD_SECONDS,
        firstDrawOpensAt: _getFirstDrawOpensAt(),
        smoothing: _getContributionsSmoothing(),
        grandPrizePeriodDraws: GRAND_PRIZE_PERIOD_DRAWS,
        numberOfTiers: MIN_NUMBER_OF_TIERS,
        tierShares: TIER_SHARES,
        reserveShares: RESERVE_SHARES
      })
    );

    console2.log("constructing auction....");

    RngRelayAuction rngRelayAuction = new RngRelayAuction(
      prizePool,
      AUCTION_DURATION,
      AUCTION_TARGET_SALE_TIME,
      address(rngAuctionRelayerDirect),
      FIRST_AUCTION_TARGET_REWARD_FRACTION,
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

    vm.stopBroadcast();
  }
}
