// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/console2.sol";

import { ScriptBase, Configuration } from "./ScriptBase.sol";

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { ud2x18 } from "prb-math/UD2x18.sol";
import { sd1x18 } from "prb-math/SD1x18.sol";

import { ClaimerFactory } from "pt-v5-claimer/ClaimerFactory.sol";
import { TpdaLiquidationPairFactory } from "pt-v5-tpda-liquidator/TpdaLiquidationPairFactory.sol";
import { TpdaLiquidationRouter } from "pt-v5-tpda-liquidator/TpdaLiquidationRouter.sol";
import { DrawManager } from "pt-v5-draw-manager/DrawManager.sol";
import { RngWitnet, IWitnetRandomness } from "pt-v5-rng-witnet/RngWitnet.sol";
import { IRng } from "pt-v5-draw-manager/interfaces/IRng.sol";
import { PrizePool, ConstructorParams, SD59x18 } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";
import { PrizeVaultFactory } from "pt-v5-vault/PrizeVaultFactory.sol";
import { RewardBurner } from "pt-v5-reward-burner/RewardBurner.sol";

contract DeployPrizePool is ScriptBase {

    function run() public {
        vm.startBroadcast();

        Configuration config = loadConfig(vm.envString("CONFIG"));

        uint twabPeriodsUntilFirstDrawPlusOne = (config.firstDrawStartsAt - block.timestamp) / config.twabPeriodLength + 1;

        TwabController twabController = new TwabController(
            config.twabPeriodLength,
            config.firstDrawStartsAt - (twabPeriodsUntilFirstDrawPlusOne * config.twabPeriodLength)
        );

        TpdaLiquidationPairFactory liquidationPairFactory = new TpdaLiquidationPairFactory();
        new TpdaLiquidationRouter(liquidationPairFactory);
        new PrizeVaultFactory();

        IRng rng = new RngWitnet(IWitnetRandomness(config.witnetRandomnessV2));

        PrizePool prizePool = new PrizePool(
            ConstructorParams(
                config.prizeToken,
                twabController,
                address(this),
                config.tierLiquidityUtilizationRate,
                config.drawPeriodSeconds,
                config.firstDrawStartsAt,
                config.grandPrizePeriodDraws,
                config.numberOfTiers,
                config.tierShares,
                config.canaryShares,
                config.reserveShares,
                config.drawTimeout
            )
        );

        RewardBurner rewardBurnerPair = new RewardBurner(
            prizePool,
            config.rewardBurnerBurnToken,
            address(this)
        );

        TpdaLiquidationPair rewardBurnerPairPair = liquidationPairFactory.createPair(
            rewardBurnerPair,
            config.rewardBurnerBurnToken,
            address(config.prizeToken),
            config.rewardBurnerTargetAuctionPeriod,
            config.rewardBurnerInitialAuctionPrice,
            config.rewardBurnerSmoothingFactor
        );

        rewardBurnerPair.setLiquidationPair(address(rewardBurnerPairPair));

        DrawManager drawManager = new DrawManager(
            prizePool,
            rng,
            config.drawAuctionDuration,
            config.drawAuctionTargetSaleTime,
            config.drawAuctionTargetFirstSaleFraction,
            config.drawAuctionTargetFirstSaleFraction,
            config.drawAuctionMaxReward,
            address(rewardBurnerPair)
        );

        prizePool.setDrawManager(address(drawManager));

        ClaimerFactory claimerFactory = new ClaimerFactory();

        claimerFactory.createClaimer(
            prizePool,
            config.claimerMinFee,
            config.claimerMaxFee,
            (config.drawPeriodSeconds - (2 * config.drawAuctionDuration)) / 2,
            config.claimerMaxFeePercent
        );

        vm.stopBroadcast();
    }
}
