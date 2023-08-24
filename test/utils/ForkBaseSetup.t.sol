// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { LinkTokenInterface } from "chainlink/interfaces/LinkTokenInterface.sol";
import { VRFV2WrapperInterface } from "chainlink/interfaces/VRFV2WrapperInterface.sol";

import { IRngAuction } from "pt-v5-chainlink-vrf-v2-direct/interfaces/IRngAuction.sol";
import { ChainlinkVRFV2Direct } from "pt-v5-chainlink-vrf-v2-direct/ChainlinkVRFV2Direct.sol";
import { ChainlinkVRFV2DirectRngAuctionHelper } from "pt-v5-chainlink-vrf-v2-direct/ChainlinkVRFV2DirectRngAuctionHelper.sol";

import { RNGInterface } from "rng/RNGInterface.sol";
import { RngAuction } from "pt-v5-draw-auction/RngAuction.sol";
import { RngAuctionRelayerDirect } from "pt-v5-draw-auction/RngAuctionRelayerDirect.sol";
import { RngRelayAuction } from "pt-v5-draw-auction/RngRelayAuction.sol";

import { PrizePool, ConstructorParams, SD59x18 } from "pt-v5-prize-pool/PrizePool.sol";
import { ud2x18 } from "prb-math/UD2x18.sol";
import { sd1x18 } from "prb-math/SD1x18.sol";
import { convert } from "prb-math/SD59x18.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";
import { Claimer } from "pt-v5-claimer/Claimer.sol";
import { ILiquidationSource } from "pt-v5-liquidator-interfaces/ILiquidationSource.sol";
import { LiquidationPair } from "pt-v5-cgda-liquidator/LiquidationPair.sol";
import { LiquidationPairFactory } from "pt-v5-cgda-liquidator/LiquidationPairFactory.sol";
import { LiquidationRouter } from "pt-v5-cgda-liquidator/LiquidationRouter.sol";
import { Vault } from "pt-v5-vault/Vault.sol";
import { YieldVault } from "pt-v5-vault-mock/YieldVault.sol";

import { Utils } from "./Utils.t.sol";

contract ForkBaseSetup is Test {
  /* ============ Variables ============ */
  Utils internal utils;

  address payable[] internal users;
  address internal owner;
  address internal manager;
  address internal alice;
  address internal bob;

  address public constant SPONSORSHIP_ADDRESS = address(1);

  LinkTokenInterface public linkToken;
  VRFV2WrapperInterface public vrfV2Wrapper;
  ChainlinkVRFV2Direct public rng;
  ChainlinkVRFV2DirectRngAuctionHelper public chainlinkRngAuctionHelper;
  RngAuction public rngAuction;
  RngAuctionRelayerDirect public rngAuctionRelayerDirect;
  RngRelayAuction public rngRelayAuction;

  Vault public vault;
  string public vaultName = "PoolTogether aEthDAI Prize Token (PTaEthDAI)";
  string public vaultSymbol = "PTaEthDAI";

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
  uint32 public drawPeriodSeconds = 1 days;
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

    underlyingAssetAddress = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC token on Ethereum
    underlyingAsset = IERC20(underlyingAssetAddress);

    prizeTokenAddress = address(0x0cEC1A9154Ff802e7934Fc916Ed7Ca50bDE6844e); // POOL token on Ethereum
    prizeToken = IERC20(prizeTokenAddress);

    twabController = new TwabController(1 days, uint32(block.timestamp));

    uint64 drawStartsAt = uint64(block.timestamp);
    uint64 auctionDuration = uint64(drawPeriodSeconds / 4);
    uint64 auctionTargetSaleTime = uint64(auctionDuration / 2);

    linkToken = LinkTokenInterface(address(0x514910771AF9Ca656af840dff83E8264EcF986CA)); // LINK on Ethereum
    vrfV2Wrapper = VRFV2WrapperInterface(address(0x5A861794B927983406fCE1D062e00b9368d97Df6)); // VRF V2 Wrapper on Ethereum

    uint32 _chainlinkCallbackGasLimit = 1_000_000;
    uint16 _chainlinkRequestConfirmations = 3;
    rng = new ChainlinkVRFV2Direct(
      address(this), // owner
      linkToken,
      vrfV2Wrapper,
      _chainlinkCallbackGasLimit,
      _chainlinkRequestConfirmations
    );

    rngAuction = new RngAuction(
      RNGInterface(rng),
      address(this),
      drawPeriodSeconds,
      drawStartsAt,
      auctionDuration,
      auctionTargetSaleTime
    );

    rngAuctionRelayerDirect = new RngAuctionRelayerDirect(rngAuction);

    chainlinkRngAuctionHelper = new ChainlinkVRFV2DirectRngAuctionHelper(
      rng,
      IRngAuction(address(rngAuction))
    );

    prizePool = new PrizePool(
      ConstructorParams(
        prizeToken,
        twabController,
        address(0),
        drawPeriodSeconds,
        drawStartsAt,
        sd1x18(0.9e18), // alpha
        12,
        uint8(3), // minimum number of tiers
        100,
        100
      )
    );

    rngRelayAuction = new RngRelayAuction(
      prizePool,
      address(rngAuctionRelayerDirect),
      auctionDuration,
      auctionTargetSaleTime
    );

    claimer = new Claimer(prizePool, 0.0001e18, 1000e18, drawPeriodSeconds, ud2x18(0.5e18));

    vault = new Vault(
      underlyingAsset,
      vaultName,
      vaultSymbol,
      twabController,
      _yieldVault,
      prizePool,
      address(claimer),
      address(this),
      100000000, // 0.1 = 10%
      address(this)
    );

    vm.makePersistent(address(vault));

    liquidationPairFactory = new LiquidationPairFactory();
    liquidationRouter = new LiquidationRouter(liquidationPairFactory);

    uint128 _virtualReserveIn = 10e18;
    uint128 _virtualReserveOut = 5e18;

    // this is approximately the maximum decay constant, as the CGDA formula requires computing e^(decayConstant * time).
    // since the data type is SD59x18 and e^134 ~= 1e58, we can divide 134 by the draw period to get the max decay constant.
    SD59x18 _decayConstant = convert(130).div(convert(int(uint(drawPeriodSeconds))));
    liquidationPair = liquidationPairFactory.createPair(
      ILiquidationSource(vault),
      address(prizeToken),
      address(vault),
      drawPeriodSeconds,
      uint32(drawStartsAt),
      uint32(drawPeriodSeconds / 2),
      _decayConstant,
      uint104(_virtualReserveIn),
      uint104(_virtualReserveOut),
      _virtualReserveOut // just make it up
    );

    vault.setLiquidationPair(liquidationPair);
  }
}
