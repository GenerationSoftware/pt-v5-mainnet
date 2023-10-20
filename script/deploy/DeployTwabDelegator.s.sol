// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";
import { TwabDelegator } from "pt-v5-twab-delegator/TwabDelegator.sol";
import { Vault } from "pt-v5-vault/Vault.sol";

import { ScriptHelpers } from "../helpers/ScriptHelpers.sol";

contract DeployTwabDelegator is ScriptHelpers {
  function _deployTwabDelegator(
    TwabController _twabController,
    string memory _tokenName,
    string memory _tokenSymbol,
    Vault _vault
  ) internal {
    new TwabDelegator(
      string.concat("Staked ", _tokenName),
      string.concat("stk", _tokenSymbol),
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
      PT_USDC_NAME,
      PT_USDC_SYMBOL,
      _getVault(
        OPTIMISM_USDC_ADDRESS,
        PT_USDC_NAME,
        PT_USDC_SYMBOL,
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
      PT_WETH_NAME,
      PT_WETH_SYMBOL,
      _getVault(
        OPTIMISM_WETH_ADDRESS,
        PT_WETH_NAME,
        PT_WETH_SYMBOL,
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
