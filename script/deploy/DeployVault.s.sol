// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC4626 } from "openzeppelin/interfaces/IERC4626.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { ud2x18 } from "prb-math/UD2x18.sol";
import { SD59x18, convert } from "prb-math/SD59x18.sol";
import { sd1x18 } from "prb-math/SD1x18.sol";

import { TwabController } from "pt-v5-twab-controller/TwabController.sol";
import { Claimer } from "pt-v5-claimer/Claimer.sol";
import { ILiquidationSource } from "pt-v5-liquidator-interfaces/ILiquidationSource.sol";
import { LiquidationPair } from "pt-v5-cgda-liquidator/LiquidationPair.sol";
import { LiquidationPairFactory } from "pt-v5-cgda-liquidator/LiquidationPairFactory.sol";
import { LiquidationRouter } from "pt-v5-cgda-liquidator/LiquidationRouter.sol";
import { PrizePool, SD59x18 } from "pt-v5-prize-pool/PrizePool.sol";
import { Vault } from "pt-v5-vault/Vault.sol";


import { ScriptHelpers } from "../helpers/ScriptHelpers.sol";

contract DeployVault is ScriptHelpers {
  uint128 public constant ONE_POOL = 1e18;

  function _deployVault(
    IERC4626 _yieldVault,
    uint128 _tokenOutPerPool
  ) internal returns (Vault vault) {
    ERC20 _underlyingAsset = ERC20(_yieldVault.asset());

    PrizePool prizePool = _getPrizePool();

    vault = new Vault(
      _underlyingAsset,
      string.concat("PoolTogether ", _underlyingAsset.name(), " Prize Token"),
      string.concat("PT", _underlyingAsset.symbol(), "T"),
      _getTwabController(),
      _yieldVault,
      prizePool,
      address(_getClaimer()),
      msg.sender,
      100000000, // 0.1 = 10%
      msg.sender
    );

    vault.setLiquidationPair(_createPair(prizePool, vault, _tokenOutPerPool));
  }

  function _createPair(
    PrizePool _prizePool,
    Vault _vault,
    uint128 _tokenOutPerPool
  ) internal returns (LiquidationPair pair) {
    // this is approximately the maximum decay constant, as the CGDA formula requires computing e^(decayConstant * time).
    // since the data type is SD59x18 and e^134 ~= 1e58, we can divide 134 by the draw period to get the max decay constant.
    SD59x18 _decayConstant = convert(130).div(convert(int(uint(_prizePool.drawPeriodSeconds()))));
    pair = _getLiquidationPairFactory().createPair(
      ILiquidationSource(_vault),
      address(_getToken("POOL")),
      address(_vault),
      _prizePool.drawPeriodSeconds(),
      uint32(_prizePool.firstDrawStartsAt()),
      _prizePool.drawPeriodSeconds() / 2,
      _decayConstant,
      uint104(ONE_POOL),
      uint104(_tokenOutPerPool),
      uint104(_tokenOutPerPool) // Assume min is 1 POOL worth of the token
    );
  }

  function _deployVaults() internal {
    /* USDC */
    _deployVault(_getAaveV3YieldVault("waUSDC"), _getExchangeRate(USDC_PRICE, 12));

    /* wETH */
    _deployVault(_getAaveV3YieldVault("waWETH"), _getExchangeRate(ETH_PRICE, 0));
  }

  function run() public {
    vm.startBroadcast();
    _deployVaults();
    vm.stopBroadcast();
  }
}
