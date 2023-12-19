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
import { VaultV2 as Vault } from "pt-v5-vault/Vault.sol";
import { VaultFactoryV2 as VaultFactory } from "pt-v5-vault/VaultFactory.sol";

import { ScriptHelpers } from "../helpers/ScriptHelpers.sol";

contract DeployVault is ScriptHelpers {
  function _deployVault(
    string memory _tokenName,
    string memory _tokenSymbol,
    IERC4626 _yieldVault,
    uint104 _exchangeRateAssetsPerPool,
    uint104 _minAuctionSize
  ) internal returns (Vault vault) {
    ERC20 _underlyingAsset = ERC20(_yieldVault.asset());

    PrizePool prizePool = _getPrizePool();

    VaultFactory vaultFactory = _getVaultFactory();

    address _vaultAddress = vaultFactory.deployVault(
      _underlyingAsset,
      _tokenName,
      _tokenSymbol,
      _yieldVault,
      prizePool,
      address(_getClaimer()),
      YIELD_FEE_RECIPIENT,
      YIELD_FEE_PERCENTAGE,
      msg.sender // Need to keep ownership to set the LiquidationPair
    );

    vault = Vault(_vaultAddress);

    vault.setLiquidationPair(
      _createPair(prizePool, vault, _exchangeRateAssetsPerPool, _minAuctionSize)
    );
  }

  function _createPair(
    PrizePool _prizePool,
    Vault _vault,
    uint104 _exchangeRateAssetsPerPool,
    uint104 _minAuctionSize
  ) internal returns (address) {
    uint48 _drawPeriodSeconds = _prizePool.drawPeriodSeconds();

    LiquidationPair pair = _getLiquidationPairFactory().createPair(
      ILiquidationSource(_vault),
      address(_getToken("POOL")),
      address(_vault),
      uint32(_drawPeriodSeconds),
      uint32(_prizePool.firstDrawOpensAt()),
      _getTargetFirstSaleTime(uint32(_drawPeriodSeconds)),
      _getDecayConstant(),
      1e18, // 1 POOL
      _exchangeRateAssetsPerPool,
      _minAuctionSize
    );

    return address(pair);
  }

  function run() public {
    vm.startBroadcast();

    /* USDC */
    _deployVault(
      PT_USDC_NAME,
      PT_USDC_SYMBOL,
      _getAaveV3YieldVault(OPTIMISM_USDC_ADDRESS),
      0.49e6,
      4e6
    );

    // POOL / USDC = 0.49
    // WETH / USDC = 1560
    // WETH / POOL = 3122
    // => 1 POOL = 1 / 3122 WETH

    /* wETH */
    _deployVault(
      PT_WETH_NAME,
      PT_WETH_SYMBOL,
      _getAaveV3YieldVault(OPTIMISM_WETH_ADDRESS),
      0.000320307495195387e18,
      0.000320307495195387e18 * 8
    );

    vm.stopBroadcast();
  }
}
