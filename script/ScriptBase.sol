// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { UD2x18, ud2x18 } from "prb-math/UD2x18.sol";
import { sd1x18 } from "prb-math/SD1x18.sol";
import { SafeCast } from "openzeppelin/utils/math/SafeCast.sol";

struct Configuration {
    // Twab Controller
    uint32 twabPeriodLength; // TWAB_PERIOD_LENGTH

    // Prize Pool
    uint256 tierLiquidityUtilizationRate;
    uint32 drawPeriodSeconds;
    uint48 firstDrawStartsIn;
    uint24 grandPrizePeriodDraws;
    uint8 numberOfTiers;
    uint8 tierShares;
    uint8 canaryShares;
    uint8 reserveShares;
    uint24 drawTimeout;
    address prizeToken;

    // Stake to Win Vault
    address stakedAsset;
    string stakingVaultName;
    string stakingVaultSymbol;
    string stakingPrizeVaultName;
    string stakingPrizeVaultSymbol;
    
    // RNG
    address rng;
    string rngType;
    
    // Draw Manager config
    uint48 drawAuctionDuration;
    uint48 drawAuctionTargetSaleTime;
    UD2x18 drawAuctionTargetFirstSaleFraction;
    uint256 drawAuctionMaxReward;
    uint256 drawAuctionMaxRetries;

    // Claimer config
    uint256 claimerTimeToReachMaxFee;
    UD2x18 claimerMaxFeePercent;
}

contract ScriptBase is Script {
    using SafeCast for uint256;

    function loadConfig(string memory filepath) internal view returns (Configuration memory config) {
        string memory file = vm.readFile(filepath);

        // Twab Controller
        config.twabPeriodLength                     = 1 hours;

        // Prize Pool
        config.tierLiquidityUtilizationRate         = vm.parseJsonUint(file, "$.prize_pool.tier_liquidity_utilization_rate");
        config.drawPeriodSeconds                    = vm.parseJsonUint(file, "$.prize_pool.draw_period_seconds").toUint32();
        config.firstDrawStartsIn                    = vm.parseJsonUint(file, "$.prize_pool.first_draw_starts_in").toUint48();
        config.grandPrizePeriodDraws                = vm.parseJsonUint(file, "$.prize_pool.grand_prize_period_draws").toUint24();
        config.numberOfTiers                        = vm.parseJsonUint(file, "$.prize_pool.number_of_tiers").toUint8();
        config.tierShares                           = vm.parseJsonUint(file, "$.prize_pool.tier_shares").toUint8();
        config.canaryShares                         = vm.parseJsonUint(file, "$.prize_pool.canary_shares").toUint8();
        config.reserveShares                        = vm.parseJsonUint(file, "$.prize_pool.reserve_shares").toUint8();
        config.drawTimeout                          = vm.parseJsonUint(file, "$.prize_pool.draw_timeout").toUint24();
        config.prizeToken                           = vm.parseJsonAddress(file, "$.prize_pool.prize_token");

        // Stake to Win Vault
        config.stakedAsset                          = vm.parseJsonAddress(file, "$.stake_to_win.staking_vault.asset");
        config.stakingVaultName                     = vm.parseJsonString(file, "$.stake_to_win.staking_vault.name");
        config.stakingVaultSymbol                   = vm.parseJsonString(file, "$.stake_to_win.staking_vault.symbol");
        config.stakingPrizeVaultName                = vm.parseJsonString(file, "$.stake_to_win.prize_vault.name");
        config.stakingPrizeVaultSymbol              = vm.parseJsonString(file, "$.stake_to_win.prize_vault.symbol");
        
        // RNG
        config.rng                                  = vm.parseJsonAddress(file, "$.rng.contract");
        config.rngType                              = vm.parseJsonString(file, "$.rng.type");
        
        // Draw Manager config
        config.drawAuctionDuration                  = vm.parseJsonUint(file, "$.draw_manager.draw_auction_duration").toUint48();
        config.drawAuctionTargetSaleTime            = vm.parseJsonUint(file, "$.draw_manager.draw_auction_target_sale_time").toUint48();
        config.drawAuctionTargetFirstSaleFraction   = ud2x18(vm.parseJsonUint(file, "$.draw_manager.draw_auction_target_first_sale_fraction").toUint64());
        config.drawAuctionMaxReward                 = vm.parseJsonUint(file, "$.draw_manager.draw_auction_max_reward");
        config.drawAuctionMaxRetries                = vm.parseJsonUint(file, "$.draw_manager.draw_auction_max_retries");

        // Claimer config
        config.claimerTimeToReachMaxFee             = vm.parseJsonUint(file, "$.claimer.time_to_reach_max_fee");
        config.claimerMaxFeePercent                 = ud2x18(vm.parseJsonUint(file, "$.claimer.max_fee_percent").toUint64());
    }

}