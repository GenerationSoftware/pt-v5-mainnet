// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/console2.sol";

import { ScriptBase, Configuration } from "./ScriptBase.sol";
import { SafeCast } from "openzeppelin/utils/math/SafeCast.sol";

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { ud2x18 } from "prb-math/UD2x18.sol";
import { sd1x18 } from "prb-math/SD1x18.sol";

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { ClaimerFactory } from "pt-v5-claimer/ClaimerFactory.sol";
import { TpdaLiquidationPairFactory, TpdaLiquidationPair } from "pt-v5-tpda-liquidator/TpdaLiquidationPairFactory.sol";
import { TpdaLiquidationRouter } from "pt-v5-tpda-liquidator/TpdaLiquidationRouter.sol";
import { DrawManager } from "pt-v5-draw-manager/DrawManager.sol";
import { RngWitnet, IWitnetRandomness } from "pt-v5-rng-witnet/RngWitnet.sol";
import { IRng } from "pt-v5-draw-manager/interfaces/IRng.sol";
import { PrizePool, ConstructorParams, SD59x18 } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";
import { PrizeVaultFactory } from "pt-v5-vault/PrizeVaultFactory.sol";
import { RewardBurner } from "pt-v5-reward-burner/RewardBurner.sol";

contract DeployPrizePool is ScriptBase {
    using SafeCast for uint256;

    Configuration config;

    constructor() {
        config = loadConfig(vm.envString("CONFIG"));
    }

    function run() public {
        vm.startBroadcast();

        uint48 firstDrawStartsAt = uint48(block.timestamp + config.firstDrawStartsIn);

        TwabController twabController = new TwabController(
            config.twabPeriodLength,
            (firstDrawStartsAt - 
                ((firstDrawStartsAt - block.timestamp) / config.twabPeriodLength + 1) * config.twabPeriodLength
            ).toUint32()
        );

        TpdaLiquidationPairFactory liquidationPairFactory = new TpdaLiquidationPairFactory();
        new TpdaLiquidationRouter(liquidationPairFactory);
        new PrizeVaultFactory();

        IRng rng = new RngWitnet(IWitnetRandomness(config.witnetRandomnessV2));

        PrizePool prizePool = new PrizePool(
            ConstructorParams(
                IERC20(config.prizeToken),
                twabController,
                msg.sender,
                config.tierLiquidityUtilizationRate,
                config.drawPeriodSeconds,
                firstDrawStartsAt,
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
            msg.sender
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
