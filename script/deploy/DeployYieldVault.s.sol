// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { ERC20Mintable } from "../../src/ERC20Mintable.sol";
import { VaultMintRate } from "../../src/VaultMintRate.sol";
import { YieldVaultMintRate } from "../../src/YieldVaultMintRate.sol";

import { Helpers } from "../helpers/Helpers.sol";

contract DeployYieldVault is Helpers {
  function _deployYieldVault(
    ERC20Mintable _underlyingAsset
  ) internal returns (YieldVaultMintRate) {
    string memory _underlyingAssetName = _underlyingAsset.name();
    string memory _underlyingAssetSymbol = _underlyingAsset.symbol();

    return
      new YieldVaultMintRate(
        _underlyingAsset,
        string.concat("PoolTogether ", _underlyingAssetName, " ", _nameSuffix, " Yield"),
        string.concat("PT", _underlyingAssetSymbol, _symbolSuffix, "Y"),
        msg.sender
      );
  }

  function _deployYieldVaults() internal {
    /* USDC */
    ERC20Mintable usdc = _getToken("USDC", _stableTokenDeployPath);
    _deployYieldVault(usdc, "Low", "L");

    /* wETH */
    ERC20Mintable wETH = _getToken("WETH", _tokenDeployPath);
    _deployYieldVault(wETH, "", "");
  }

  function run() public {
    vm.startBroadcast();
    _deployYieldVaults();
    vm.stopBroadcast();
  }
}
