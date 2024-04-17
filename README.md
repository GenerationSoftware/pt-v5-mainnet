# PoolTogether V5 Mainnet

PoolTogether V5 production deployment scripts.

## Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Prize Pool Parameters](#prize-pool-parameters)
- [Stake to Win Parameters](#stake-to-win-parameters)
- [RNG Parameters](#rng-parameters)
- [Draw Manager Parameters](#draw-manager-parameters)
- [Claimer Parameters](#claimer-parameters)
- [Deployment](#deployment)

## Installation

### Dependencies

You may have to install the following tools to use this repository:

- [Node.js](https://nodejs.org/) to run scripts
- [yarn](https://yarnpkg.com/) to install node.js dependencies
- [Foundry](https://github.com/foundry-rs/foundry) to compile and test contracts
- [direnv](https://direnv.net/) (or a similar tool) to set environment variables

Install dependencies:

```
yarn install
```

### Env

Make a copy of `.envrc.example` and write down the env variables needed to run this project.

```
cp .envrc.example .envrc
```

Once your env variables are setup, load them with:

```
direnv allow
```

### Compile

Run the following command to compile the contracts:

```
yarn compile
```

## Configuration

Each deployment of PoolTogether V5 must be tuned to meet the requirements of the chain and environment it will live on. These configuration parameters will affect the efficiency, safety, and endurance of the prize pool and peripheral contracts and should be defined with intent.

All configurable parameters are located in the [config](./config/) folder and are separated by chain name. If the target chain does not have it's own configuration file, then a new one can be created an modified based on the deployment requirements.

Each parameter in a configuration file is separated by category.

## Prize Pool Parameters

The prize pool parameters modify the core behaviour of the PrizePool and TwabController contracts and may also affect the reasoning behind some of the other parameters, such as the draw manager `draw_auction_duration` or the claimer `time_to_reach_max_fee`.

--------------------------------------------------------------------------------

### `tier_liquidity_utilization_rate`

The tier liquidity utilization rate defines the target amount of the stored liquidity that should be used for prizes for each prize tier. It is defined as an 18 decimal fraction ranging from (0.0, 1.0].

If set too high, some prizes may be frequently over-awarded such that not all wins are sent a prize, resulting in a race condition for claimers to claim certain prizes over others.

If set very low, the prize pool may avoid these race conditions, but will be somewhat inefficient and incapable of adapting quickly to fluctuating markets.

It is generally recommended to leave this value at 0.5 (5e17) to avoid race conditions while still allowing the prize pool to adapt fairly quickly to market fluctuations.

--------------------------------------------------------------------------------

### `draw_period_seconds`

The draw period is the regular time interval at which individual draws will commence. For example, if the draw period is set to 1 day, there will be a draw that closes every day. The draw period should be set based on the projected amount of time that it will take for deposits to generate enough yield to cover draw expenses (RNG fees). It should also be enough time to generate prizes that are big enough to be claimed without the claim fee needing to exceed a reasonable percentage of the prize amount.

Generally, most L2 deployments are cheap enough for daily draws as long as there are ample deposits (ballpark $1m TVL at 3% APR). An Ethereum mainnet deployment might need a much longer period, such as 1-2 weeks to ensure the protocol does not spend too much of the yield generation on operating expenses.

--------------------------------------------------------------------------------

### `first_draw_starts_in`

This parameter defines the relative start time of the first draw compared to the deployment time. For example, if this parameter is set to 600 seconds, and the prize pool is deployed at 6:15, then the first draw will open at 6:25.

--------------------------------------------------------------------------------

### `grand_prize_period_draws`

This value defines how many draws should pass on average before the grand prize (GP) is awarded. However, this does not guarantee that the GP will be awarded within this time frame since prizes are distributed based on a statistical model.

The longer this period is, the bigger the GP will grow before being awarded. This value should be chosen based on the expected yield generation of the system and the desired GP size.

--------------------------------------------------------------------------------

### `number_of_tiers`

This defines the starting number of tiers for the prize pool. Unless some significant prize bootstrapping is planned, this value should be left at the minimum so that it can grow as needed once yield is generated.

--------------------------------------------------------------------------------

### `tier_shares`

The tier shares, canary shares, and reserve shares are all relative to each other. The tier shares represent the relative amount of yield that each non-canary prize tier will receive as liquidity each draw. It is typically set to some arbitrary value such as 100 and the canary and reserve shares are then set relative to the tier share value.

--------------------------------------------------------------------------------

### `canary_shares`

The canary shares represent the relative amount of yield that each canary tier will receive as liquidity each draw. The smaller the canary share value is set, the bigger the daily prizes will be for the prize pool (as the daily prizes grow, they become less-frequent as well).

Canary tiers are meant to be used for claim gas discovery and can be considered a prize pool operating expense, so they should be set low enough such that the average yield spent on the canary tiers does not exceed a target threshold (1% of total daily yield can be considered a good benchmark).

--------------------------------------------------------------------------------

### `reserve_shares`

The reserve is somewhat multi-purpose based on the deployment needs, but in this script it is set up such that it pays for the RNG costs every draw and the leftover is contributed back to the prize pool on behalf of a special prize vault (such as a POOL staking vault). Depositors in this vault then have a chance to win even though the vault has no yield source.

As such, the reserve shares should be tuned to cover the daily RNG costs under expected operating conditions and can be increased from the minimum requirement to send more contributions to the staking vault.

--------------------------------------------------------------------------------

### `draw_timeout`

The draw timeout is the number of draws that must pass without being awarded before the prize pool shuts down. Once shutdown, the prize pool will open withdrawals based on user TWAB for any remaining liquidity. This should be set high enough such that it is improbable for the prize pool to accidentally shutdown in normal operating conditions.

--------------------------------------------------------------------------------

### `prize_token`

The prize token parameter is the address of the token that the prize pool will use for prizes. All prize vaults will be expected to contribute this token and only this token to the prize pool to generate a winning chance. It is generally recommended to use a token that has deep liquidity and is universally accepted (such as WETH) to make yield liquidations and prize wins as cheap and easy as possible.

--------------------------------------------------------------------------------

## Stake to Win Parameters

The script sets up a prize vault that accepts a certain token as deposits and uses the leftover reserve each draw to generating winning chance for all depositors. For example, if POOL is used, users can deposit POOL to the prize vault to have a chance to win each draw.

--------------------------------------------------------------------------------

### `staking_vault.asset`

This is the address of the ERC20 token that the underlying staking vault will accept as deposits.

--------------------------------------------------------------------------------

### `staking_vault.name`

This defines the name of the underlying staking vault's share token.

--------------------------------------------------------------------------------

### `staking_vault.symbol`

This defines the symbol used for the underlying staking vault's share token.

--------------------------------------------------------------------------------

### `prize_vault.name`

This defines the name of the prize vault's share token.

--------------------------------------------------------------------------------

### `prize_vault.symbol`

This defines the symbol of the prize vault's share token.

--------------------------------------------------------------------------------

## RNG Parameters

The RNG follows a standardized interface so that it can be plugged into the `DrawManager` contract and it's completion can be auctioned every draw.

--------------------------------------------------------------------------------

### `contract`

This is the address of the RNG contract of the specified type.

--------------------------------------------------------------------------------

### `type`

This defines the type of the RNG contract. If the contract is already standardized, then this should be set to `standardized`.

Other supported types include:

- `witnet-randomness-v2` The witnet v2 randomness contract

--------------------------------------------------------------------------------

### Draw Manager Parameters

The draw manager runs incentivised auctions to generate random numbers and award each draw.

--------------------------------------------------------------------------------

### `draw_auction_duration`

This is the maximum duration that each auction will last. There can be multiple auctions for each draw so it's important to set this such that all auctions can complete with enough time left over for all the prize claims to be completed before the next draw closes.

--------------------------------------------------------------------------------

### `draw_auction_target_sale_time`

The target sale time is the time at which each auction will reach the expected sale price (based on the last auction results). It should be set somewhere around 1/4 to 1/2 of the auction duration. If it is set too short, it can result in granularity loss in the auction price which can lead to overpaying for RNG costs.

--------------------------------------------------------------------------------

### `draw_auction_target_first_sale_fraction`

The target first sale fraction defines the expected portion of the reserve that will be needed to pay for the first auctions. Setting this to 0.5 (in 18 decimal format) will generally yield optimal results. This will only affect the first draw.

--------------------------------------------------------------------------------

### `draw_auction_max_reward`

This value sets a max cap on the price of each auction. This should be a reasonably large value such that it would never need to be exceeded under expected operating conditions. It is defined as an amount of the prize pool `prize_token`.

--------------------------------------------------------------------------------

## Claimer Parameters

The claimer runs an incentivised auction for prize claims to be made on behalf of the winners. Prize vaults will opt-in to using the claimer or an alternate strategy can be used if needed.

--------------------------------------------------------------------------------

### `time_to_reach_max_fee`

This is the time in seconds that will pass before the reward per claim reaches the max for the prize tier. It should be set to about half of the expected time for all claims to be made or less.

--------------------------------------------------------------------------------

### `max_fee_percent`

The max fee percent is a fraction with 18 decimals that determines how much of each prize can be used for claimer rewards. For example, if this is set to 0.1, up to 10% of the prize value can be used to reward the claim. This parameter acts as a safety net for winners in the case of network outages or other issues that prevent the timely claiming of prizes.

--------------------------------------------------------------------------------

## Deployment

To deploy a new prize pool, first ensure the following steps have been completed:

1. set relevant environment variables (RPC URLs, deployer address and private key, etherscan API key)
2. configure the deployment parameters in a JSON file

### Deploy a New Prize Pool

To deploy a new prize pool and supporting contracts, first follow the steps above and then run the NPM command in the `package.json` file that corresponds to the chain you wish to deploy on. For example, to deploy on optimism, run `npm run deploy:optimism`.

If a script is not setup for your target chain, first create a new config file for the chain and then copy one of the existing NPM commands and modify it to match your desired configuration.

After deployment, contracts will automatically be verified on etherscan using your set etherscan API key for the relevant chain.

### Contract List

To generate the contract list for a deployment, run the following command: `npm run gen:deployments`. The deployment contract lists will be output to the `deployments` folder as JSON files.
