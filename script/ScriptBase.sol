// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { SafeCast } from "openzeppelin/utils/math/SafeCast.sol";

struct Configuration {
    // Twab Controller
    uint256 twabPeriodLength; // TWAB_PERIOD_LENGTH

    // Prize Pool
    uint256 tierLiquidityUtilizationRate;
    uint32 drawPeriodSeconds;
    uint48 firstDrawStartsAt;
    uint24 grandPrizePeriodDraws;
    uint8 numberOfTiers;
    uint8 tierShares;
    uint8 canaryShares;
    uint8 reserveShares;
    uint32 drawTimeout;
    address prizeToken;

    // Reward Burner
    address rewardBurnerBurnToken;
    uint64 rewardBurnerTargetAuctionPeriod;
    uint192 rewardBurnerInitialAuctionPrice;
    uint256 rewardBurnerSmoothingFactor;
    
    // RNG
    address witnetRandomnessV2;
    
    // Draw Manager config
    uint48 drawAuctionDuration;
    uint48 drawAuctionTargetSaleTime;
    uint48 drawAuctionTargetFirstSaleFraction;
    uint48 drawAuctionMaxReward;

    // Claimer config
    uint256 claimerMinFee;
    uint256 claimerMaxFee;
    uint256 claimerMaxFeePercent;
}

contract ScriptBase is Script {
    using SafeCast for uint256;

    function loadConfig(string memory filepath) internal pure returns (Configuration memory config) {
        string memory file = vm.readFile(filepath);

        // Twab Controller
        config.twabPeriodLength                     = 1 hours;

        // Prize Pool
        config.tierLiquidityUtilizationRate         = vm.parseJsonUint(config, "$.prize_pool.tier_liquidity_utilization_rate");
        config.drawPeriodSeconds                    = vm.parseJsonUint(config, "$.prize_pool.draw_period_seconds").toUint32();
        config.firstDrawStartsAt                    = vm.parseJsonUint(config, "$.prize_pool.first_draw_starts_at").toUint48();
        config.grandPrizePeriodDraws                = vm.parseJsonUint(config, "$.prize_pool.grand_prize_period_draws").toUint24();
        config.numberOfTiers                        = vm.parseJsonUint(config, "$.prize_pool.number_of_tiers").toUint8();
        config.tierShares                           = vm.parseJsonUint(config, "$.prize_pool.tier_shares").toUint8();
        config.canaryShares                         = vm.parseJsonUint(config, "$.prize_pool.canary_shares").toUint8();
        config.reserveShares                        = vm.parseJsonUint(config, "$.prize_pool.reserve_shares").toUint8();
        config.drawTimeout                          = vm.parseJsonUint(config, "$.prize_pool.draw_timeout").toUint24();
        config.prizeToken                           = vm.parseJsonAddress(config, "$.prize_pool.prize_token");

        // Reward Burner
        config.rewardBurnerBurnToken                = vm.parseJsonAddress(config, "$.reward_burner.burn_token");
        config.rewardBurnerTargetAuctionPeriod      = vm.parseJsonUint(config, "$.reward_burner.target_auction_period").toUint64();
        config.rewardBurnerInitialAuctionPrice      = vm.parseJsonUint(config, "$.reward_burner.initial_auction_price").toUint192();
        config.rewardBurnerSmoothingFactor          = vm.parseJsonUint(config, "$.reward_burner.smoothing_factor");
        
        // RNG
        config.witnetRandomnessV2                   = vm.parseJsonUint(config, "$.rng.witnet_randomness_v2");
        
        // Draw Manager config
        config.drawAuctionDuration                  = vm.parseJsonUint(config, "$.draw_auction_duration");
        config.drawAuctionTargetSaleTime            = vm.parseJsonUint(config, "$.draw_auction_target_sale_time");
        config.drawAuctionTargetFirstSaleFraction   = vm.parseJsonUint(config, "$.draw_auction_target_first_sale_fraction");
        config.drawAuctionMaxReward                 = vm.parseJsonUint(config, "$.draw_auction_max_reward");

        // Claimer config
        config.claimerMinFee                        = vm.parseJsonUint(config, "$.claimer.min_fee");
        config.claimerMaxFee                        = vm.parseJsonUint(config, "$.claimer.max_fee");
        config.claimerMaxFeePercent                 = vm.parseJsonUint(config, "$.claimer.max_fee_percent");
    }

}