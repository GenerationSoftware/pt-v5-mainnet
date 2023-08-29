// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { console2 } from "forge-std/console2.sol";

import { IRngAuction } from "pt-v5-chainlink-vrf-v2-direct/interfaces/IRngAuction.sol";
import { ChainlinkVRFV2Direct } from "pt-v5-chainlink-vrf-v2-direct/ChainlinkVRFV2Direct.sol";
import { ChainlinkVRFV2DirectRngAuctionHelper } from "pt-v5-chainlink-vrf-v2-direct/ChainlinkVRFV2DirectRngAuctionHelper.sol";

import { RNGInterface } from "rng/RNGInterface.sol";
import { RngAuction } from "pt-v5-draw-auction/RngAuction.sol";
import { RngAuctionRelayerRemoteOwner } from "pt-v5-draw-auction/RngAuctionRelayerRemoteOwner.sol";
import { RngRelayAuction } from "pt-v5-draw-auction/RngRelayAuction.sol";

import { ScriptHelpers } from "../helpers/ScriptHelpers.sol";

contract DeployL1RngAuction is ScriptHelpers {
  function run() public {
    vm.startBroadcast();

    console2.log("constructing rng stuff....");

    ChainlinkVRFV2Direct chainlinkRng = new ChainlinkVRFV2Direct(
      address(this), // TODO: who should be owner?
      _getLinkToken(),
      _getVrfV2Wrapper(),
      CHAINLINK_CALLBACK_GAS_LIMIT,
      CHAINLINK_REQUEST_CONFIRMATIONS
    );

    RngAuction rngAuction = new RngAuction(
      RNGInterface(chainlinkRng),
      address(this), // TODO: who should be owner?
      DRAW_PERIOD_SECONDS,
      _getAuctionOffset(),
      AUCTION_DURATION,
      AUCTION_TARGET_SALE_TIME
    );

    new ChainlinkVRFV2DirectRngAuctionHelper(chainlinkRng, IRngAuction(address(rngAuction)));
    new RngAuctionRelayerRemoteOwner(rngAuction);

    vm.stopBroadcast();
  }
}
