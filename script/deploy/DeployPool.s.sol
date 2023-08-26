// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/console2.sol";

import { Script } from "forge-std/Script.sol";

import { VRFV2WrapperInterface } from "chainlink/interfaces/VRFV2WrapperInterface.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { ud2x18 } from "prb-math/UD2x18.sol";
import { sd1x18 } from "prb-math/SD1x18.sol";

import { ChainlinkVRFV2Direct } from "pt-v5-chainlink-vrf-v2-direct/ChainlinkVRFV2Direct.sol";
import { ChainlinkVRFV2DirectRngAuctionHelper } from "pt-v5-chainlink-vrf-v2-direct/ChainlinkVRFV2DirectRngAuctionHelper.sol";
import { IRngAuction } from "pt-v5-chainlink-vrf-v2-direct/interfaces/IRngAuction.sol";
import { Claimer } from "pt-v5-claimer/Claimer.sol";
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
    TwabController twabController = new TwabController(TWAB_PERIOD_LENGTH, _auctionOffset());

    uint64 firstDrawStartsAt = uint64(block.timestamp);
    uint64 auctionDuration = DRAW_PERIOD_SECONDS / 4;
    uint64 auctionTargetSaleTime = auctionDuration / 2;

    console2.log("constructing rng stuff....");

    uint32 _chainlinkCallbackGasLimit = 1_000_000;
    uint16 _chainlinkRequestConfirmations = 3;
    ChainlinkVRFV2Direct chainlinkRng = new ChainlinkVRFV2Direct(
      address(this), // owner
      _getLinkToken(),
      _getVrfV2Wrapper(),
      _chainlinkCallbackGasLimit,
      _chainlinkRequestConfirmations
    );

    RngAuction rngAuction = new RngAuction(
      RNGInterface(chainlinkRng),
      address(this),
      DRAW_PERIOD_SECONDS,
      firstDrawStartsAt,
      AUCTION_DURATION,
      AUCTION_TARGET_SALE_TIME
    );

    RngAuctionRelayerDirect rngAuctionRelayerDirect = new RngAuctionRelayerDirect(rngAuction);

    new ChainlinkVRFV2DirectRngAuctionHelper(chainlinkRng, IRngAuction(address(rngAuction)));

    console2.log("constructing prize pool....");

    PrizePool prizePool = new PrizePool(
      ConstructorParams(
        prizeToken,
        twabController,
        address(0),
        DRAW_PERIOD_SECONDS,
        firstDrawStartsAt, // drawStartedAt
        sd1x18(0.9e18), // alpha
        GRAND_PRIZE_PERIOD_DRAWS,
        uint8(3), // minimum number of tiers
        TIER_SHARES,
        RESERVE_SHARES
      )
    );

    console2.log("constructing auction....");

    RngRelayAuction rngRelayAuction = new RngRelayAuction(
      prizePool,
      address(rngAuctionRelayerDirect),
      auctionDuration,
      auctionTargetSaleTime
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
