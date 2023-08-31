// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";
import { TwabDelegator } from "pt-v5-twab-delegator/TwabDelegator.sol";
import { Vault } from "pt-v5-vault/Vault.sol";

import { ScriptHelpers } from "../helpers/ScriptHelpers.sol";
contract DeployTwabDelegator is ScriptHelpers {
  function _deployTwabDelegator(TwabController _twabController, Vault _vault) internal {
    ERC20 _underlyingAsset = ERC20(_vault.asset());

    new TwabDelegator(
      string.concat("PoolTogether Staked Prize ", _underlyingAsset.name(), ""),
      string.concat("stkPT", _underlyingAsset.symbol(), ""),
      _twabController,
      _vault
    );
  }

  function _deployTwabDelegators() internal {
    PrizePool _prizePool = _getPrizePool();
    TwabController _twabController = _getTwabController();
    address _claimer = address(_getClaimer());

    /* USDC */
    _deployTwabDelegator(
      _twabController,
      _getVault(
        OPTIMISM_USDC_ADDRESS,
        "PoolTogether Prize USD Coin",
        "PTUSDC",
        _twabController,
        _getAaveV3YieldVault(OPTIMISM_USDC_ADDRESS),
        _prizePool,
        _claimer,
        YIELD_FEE_RECIPIENT,
        YIELD_FEE_PERCENTAGE,
        msg.sender
      )
    );

    /* wETH */
    _deployTwabDelegator(
      _twabController,
      _getVault(
        OPTIMISM_WETH_ADDRESS,
        "PoolTogether Prize Wrapped Ether",
        "PTWETH",
        _twabController,
        _getAaveV3YieldVault(OPTIMISM_WETH_ADDRESS),
        _prizePool,
        _claimer,
        YIELD_FEE_RECIPIENT,
        YIELD_FEE_PERCENTAGE,
        msg.sender
      )
    );
  }

  function run() public {
    vm.startBroadcast();
    _deployTwabDelegators();
    vm.stopBroadcast();
  }
}
