// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";

import { TwabController } from "pt-v5-twab-controller/TwabController.sol";
import { TwabDelegator } from "pt-v5-twab-delegator/TwabDelegator.sol";
import { Vault } from "pt-v5-vault/Vault.sol";

import { ScriptHelpers } from "../helpers/ScriptHelpers.sol";

contract DeployTwabDelegator is ScriptHelpers {
  function _deployTwabDelegator(TwabController _twabController, Vault _vault) internal {
    ERC20 _underlyingAsset = ERC20(_vault.asset());

    new TwabDelegator(
      string.concat("PoolTogether Staked ", _underlyingAsset.name(), " Prize Token"),
      string.concat("stkPT", _underlyingAsset.symbol(), "T"),
      _twabController,
      _vault
    );
  }

  function _deployTwabDelegators() internal {
    TwabController _twabController = _getTwabController();

    /* USDC */
    _deployTwabDelegator(_twabController, _getVault("PTUSDC"));

    /* wETH */
    _deployTwabDelegator(_twabController, _getVault("PTWETH"));
  }

  function run() public {
    vm.startBroadcast();
    _deployTwabDelegators();
    vm.stopBroadcast();
  }
}
