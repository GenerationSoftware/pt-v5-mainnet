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
import { TwabRewards } from "pt-v5-twab-rewards/TwabRewards.sol";
import { PrizeVaultFactory } from "pt-v5-vault/PrizeVaultFactory.sol";
import { PrizeVault, IERC4626 } from "pt-v5-vault/PrizeVault.sol";
import { StakingVault, IERC20 as StakingVaultIERC20 } from "pt-v5-staking-vault/StakingVault.sol";

contract DeployPrizePool is ScriptBase {
    using SafeCast for uint256;

    Configuration internal config;
    IRng internal standardizedRng;
    PrizePool internal prizePool;
    TwabController internal twabController;
    TpdaLiquidationPairFactory internal liquidationPairFactory;
    PrizeVault internal stakingPrizeVault;
    DrawManager internal drawManager;
    ClaimerFactory internal claimerFactory;
    StakingVault internal stakingVault;
    PrizeVaultFactory internal prizeVaultFactory;
    TpdaLiquidationRouter internal tpdaLiquidationRouter;
    address internal claimer;

    constructor() {
        config = loadConfig(vm.envString("CONFIG"));
    }

    function run() public virtual {
        vm.startBroadcast();

        if (keccak256(bytes(config.rngType)) == keccak256("witnet-randomness-v2")) {
            /// WITNET
            standardizedRng = new RngWitnet(IWitnetRandomness(config.rng));
        } else if (keccak256(bytes(config.rngType)) == keccak256("standardized")){
            /// STANDARDIZED
            standardizedRng = IRng(config.rng);
        } else {
            revert("Unknown RNG type...");
        }

        deployCore();

        vm.stopBroadcast();
    }

    function deployCore() public {
        uint48 firstDrawStartsAt = uint48(block.timestamp + config.firstDrawStartsIn);

        twabController = new TwabController(
            config.twabPeriodLength,
            (firstDrawStartsAt -
                ((firstDrawStartsAt - block.timestamp) / config.twabPeriodLength + 1) * config.twabPeriodLength
            ).toUint32()
        );
        new TwabRewards(twabController);

        liquidationPairFactory = new TpdaLiquidationPairFactory();
        tpdaLiquidationRouter = new TpdaLiquidationRouter(liquidationPairFactory);
        prizeVaultFactory = new PrizeVaultFactory();

        prizePool = new PrizePool(
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

        claimerFactory = new ClaimerFactory();
        claimer = address(claimerFactory.createClaimer(
            prizePool,
            config.claimerTimeToReachMaxFee,
            config.claimerMaxFeePercent
        ));

        stakingVault = new StakingVault(config.stakingVaultName, config.stakingVaultSymbol, StakingVaultIERC20(config.stakedAsset));
        stakingPrizeVault = new PrizeVault(
            config.stakingPrizeVaultName,
            config.stakingPrizeVaultSymbol,
            IERC4626(address(stakingVault)),
            prizePool,
            address(claimer),
            address(0), // no yield fee recipient
            0, // 0 yield fee %
            0, // 0 yield buffer
            address(msg.sender) // temporary owner, but we renounce on the next call
        );
        stakingPrizeVault.renounceOwnership();

        drawManager = new DrawManager(
            prizePool,
            standardizedRng,
            config.drawAuctionDuration,
            config.drawAuctionTargetSaleTime,
            config.drawAuctionTargetFirstSaleFraction,
            config.drawAuctionTargetFirstSaleFraction,
            config.drawAuctionMaxReward,
            config.drawAuctionMaxRetries,
            address(stakingPrizeVault)
        );

        prizePool.setDrawManager(address(drawManager));
    }
}
