// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { LinkTokenInterface } from "chainlink/interfaces/LinkTokenInterface.sol";
import { VRFV2Wrapper } from "chainlink/vrf/VRFV2Wrapper.sol";

import { IRngAuction } from "pt-v5-chainlink-vrf-v2-direct/interfaces/IRngAuction.sol";
import { ChainlinkVRFV2Direct } from "pt-v5-chainlink-vrf-v2-direct/ChainlinkVRFV2Direct.sol";
import { ChainlinkVRFV2DirectRngAuctionHelper } from "pt-v5-chainlink-vrf-v2-direct/ChainlinkVRFV2DirectRngAuctionHelper.sol";

import { RNGInterface } from "rng/RNGInterface.sol";
import { RngAuction } from "pt-v5-draw-auction/RngAuction.sol";
import { RngAuctionRelayerDirect } from "pt-v5-draw-auction/RngAuctionRelayerDirect.sol";
import { RngRelayAuction } from "pt-v5-draw-auction/RngRelayAuction.sol";

import { PrizePool, ConstructorParams } from "pt-v5-prize-pool/PrizePool.sol";
import { sd1x18 } from "prb-math/SD1x18.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";
import { Claimer } from "pt-v5-claimer/Claimer.sol";
import { ILiquidationSource } from "pt-v5-liquidator-interfaces/ILiquidationSource.sol";
import { LiquidationPair } from "pt-v5-cgda-liquidator/LiquidationPair.sol";
import { LiquidationPairFactory } from "pt-v5-cgda-liquidator/LiquidationPairFactory.sol";
import { LiquidationRouter } from "pt-v5-cgda-liquidator/LiquidationRouter.sol";
import { Vault } from "pt-v5-vault/Vault.sol";
import { YieldVault } from "pt-v5-vault-mock/YieldVault.sol";

import { Utils } from "./Utils.t.sol";
import { TestHelpers } from "./TestHelpers.t.sol";

contract ForkBaseSetup is TestHelpers {
  /* ============ Variables ============ */
  Utils internal utils;

  address payable[] internal users;
  address internal owner;
  address internal manager;
  address internal alice;
  address internal bob;

  address public constant SPONSORSHIP_ADDRESS = address(1);

  LinkTokenInterface public linkToken;
  VRFV2Wrapper public vrfV2Wrapper;
  ChainlinkVRFV2Direct public rng;
  ChainlinkVRFV2DirectRngAuctionHelper public chainlinkRngAuctionHelper;
  RngAuction public rngAuction;
  RngAuctionRelayerDirect public rngAuctionRelayerDirect;
  RngRelayAuction public rngRelayAuction;

  Vault public vault;
  string public vaultName = "PoolTogether aOpUSDC Prize Token (PTaOpUSDC)";
  string public vaultSymbol = "PTaOpUSDC";

  address public underlyingAssetAddress;
  IERC20 public underlyingAsset;

  address public prizeTokenAddress;
  IERC20 public prizeToken;

  LiquidationPairFactory public liquidationPairFactory;
  LiquidationRouter public liquidationRouter;
  LiquidationPair public liquidationPair;

  Claimer public claimer;
  PrizePool public prizePool;

  uint256 public winningRandomNumber = 123456;
  TwabController public twabController;

  /* ============ setUp ============ */
  function forkSetUp(IERC4626 _yieldVault) public {
    utils = new Utils();

    users = utils.createUsers(4);
    owner = users[0];
    manager = users[1];
    alice = users[2];
    bob = users[3];

    vm.label(owner, "Owner");
    vm.label(manager, "Manager");
    vm.label(alice, "Alice");
    vm.label(bob, "Bob");

    underlyingAssetAddress = _yieldVault.asset(); // USDC token on Optimism
    underlyingAsset = IERC20(underlyingAssetAddress);

    prizeTokenAddress = _getToken("POOL"); // POOL token on Optimism
    prizeToken = IERC20(prizeTokenAddress);

    // TODO: which period offset should we use?
    twabController = new TwabController(TWAB_PERIOD_LENGTH, uint32(block.timestamp));

    uint64 drawStartsAt = uint64(block.timestamp);

    // TODO: needs to be exported in an L1 script
    linkToken = LinkTokenInterface(address(0x514910771AF9Ca656af840dff83E8264EcF986CA)); // LINK on Ethereum
    vrfV2Wrapper = VRFV2Wrapper(address(0x5A861794B927983406fCE1D062e00b9368d97Df6)); // VRF V2 Wrapper on Ethereum

    rng = new ChainlinkVRFV2Direct(
      address(this), // owner
      vrfV2Wrapper,
      CHAINLINK_CALLBACK_GAS_LIMIT,
      CHAINLINK_REQUEST_CONFIRMATIONS
    );

    rngAuction = new RngAuction(
      RNGInterface(rng),
      address(this),
      DRAW_PERIOD_SECONDS,
      drawStartsAt,
      AUCTION_DURATION,
      AUCTION_TARGET_SALE_TIME
    );

    rngAuctionRelayerDirect = new RngAuctionRelayerDirect(rngAuction);

    chainlinkRngAuctionHelper = new ChainlinkVRFV2DirectRngAuctionHelper(
      rng,
      IRngAuction(address(rngAuction))
    );

    prizePool = new PrizePool(
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

    rngRelayAuction = new RngRelayAuction(
      prizePool,
      address(rngAuctionRelayerDirect),
      AUCTION_DURATION,
      AUCTION_TARGET_SALE_TIME,
      AUCTION_MAX_REWARD
    );

    prizePool.setDrawManager(address(rngRelayAuction));

    claimer = new Claimer(
      prizePool,
      CLAIMER_MIN_FEE,
      CLAIMER_MAX_FEE,
      DRAW_PERIOD_SECONDS,
      _getClaimerMaxFeePortionOfPrize()
    );

    vault = new Vault(
      underlyingAsset,
      vaultName,
      vaultSymbol,
      twabController,
      _yieldVault,
      prizePool,
      address(claimer),
      address(this),
      YIELD_FEE_PERCENTAGE,
      address(this)
    );

    vm.makePersistent(address(vault));

    liquidationPairFactory = new LiquidationPairFactory();
    liquidationRouter = new LiquidationRouter(liquidationPairFactory);

    uint104 _virtualReserveOut = _getExchangeRate(USDC_PRICE, 12);

    liquidationPair = liquidationPairFactory.createPair(
      ILiquidationSource(vault),
      address(prizeToken),
      address(vault),
      DRAW_PERIOD_SECONDS,
      uint32(drawStartsAt),
      _getTargetFirstSaleTime(DRAW_PERIOD_SECONDS),
      _getDecayConstant(),
      ONE_POOL,
      _virtualReserveOut,
      _virtualReserveOut
    );

    vault.setLiquidationPair(liquidationPair);
  }
}
