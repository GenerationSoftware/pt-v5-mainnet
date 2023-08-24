// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";

import { TwabController } from "pt-v5-twab-controller/TwabController.sol";
import { TwabDelegator } from "pt-v5-twab-delegator/TwabDelegator.sol";

import { VaultMintRate } from "../../src/VaultMintRate.sol";

import { Helpers } from "../helpers/Helpers.sol";

contract DeployTwabDelegator is Helpers {
  function _deployTwabDelegator(
    TwabController _twabController,
    VaultMintRate _vault
  ) internal {
    ERC20 _underlyingAsset = ERC20(_vault.asset());

    new TwabDelegator(
      string.concat("PoolTogether Staked ", _underlyingAsset.name(), _nameSuffix, " Prize Token"),
      string.concat("stkPT", _underlyingAsset.symbol(), _symbolSuffix, "T"),
      _twabController,
      _vault
    );
  }

  function _deployTwabDelegators() internal {
    TwabController _twabController = _getTwabController();

    /* USDC */
    _deployTwabDelegator(_twabController, _getVault("PTUSDCLY"));

    /* wETH */
    _deployTwabDelegator(_twabController, _getVault("PTWETHY"));
  }

  function run() public {
    vm.startBroadcast();
    _deployTwabDelegators();
    vm.stopBroadcast();
  }
}
