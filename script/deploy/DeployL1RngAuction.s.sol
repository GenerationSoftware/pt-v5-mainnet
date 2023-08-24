// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "forge-std/console2.sol";

import { IRngAuction } from "pt-v5-chainlink-vrf-v2-direct/interfaces/IRngAuction.sol";
import { ChainlinkVRFV2Direct } from "pt-v5-chainlink-vrf-v2-direct/ChainlinkVRFV2Direct.sol";
import { ChainlinkVRFV2DirectRngAuctionHelper } from "pt-v5-chainlink-vrf-v2-direct/ChainlinkVRFV2DirectRngAuctionHelper.sol";

import { RNGInterface } from "rng/RNGInterface.sol";
import { RngAuction } from "pt-v5-draw-auction/RngAuction.sol";
import { RngAuctionRelayerRemoteOwner } from "pt-v5-draw-auction/RngAuctionRelayerRemoteOwner.sol";
import { RngRelayAuction } from "pt-v5-draw-auction/RngRelayAuction.sol";

import { Helpers } from "../helpers/Helpers.sol";

import { Constants, DRAW_PERIOD_SECONDS, AUCTION_DURATION, AUCTION_TARGET_SALE_TIME, CHAINLINK_CALLBACK_GAS_LIMIT, CHAINLINK_REQUEST_CONFIRMATIONS } from "./Constants.sol";

contract DeployL1RngAuction is Helpers {
  function run() public {
    vm.startBroadcast();

    console2.log("constructing rng stuff....");

    ChainlinkVRFV2Direct chainlinkRng = new ChainlinkVRFV2Direct(
      address(this), // owner
      _getLinkToken(),
      _getVrfV2Wrapper(),
      CHAINLINK_CALLBACK_GAS_LIMIT,
      CHAINLINK_REQUEST_CONFIRMATIONS
    );

    RngAuction rngAuction = new RngAuction(
      RNGInterface(chainlinkRng),
      address(this),
      DRAW_PERIOD_SECONDS,
      Constants.auctionOffset(),
      AUCTION_DURATION,
      AUCTION_TARGET_SALE_TIME
    );

    new ChainlinkVRFV2DirectRngAuctionHelper(chainlinkRng, IRngAuction(address(rngAuction)));
    new RngAuctionRelayerRemoteOwner(rngAuction);

    vm.stopBroadcast();
  }
}
