// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";
import { IERC4626, IERC20 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { ForkAaveV3Setup } from "./ForkAaveV3Setup.t.sol";

contract LiquidateAaveV3ForkTest is ForkAaveV3Setup {
  uint256 public mainnetFork;
  uint256 public startBlock = 16_778_280;

  /* ============ Tests ============ */
//   function testLiquidate() external {
//     uint256 _amount = 10_000_000e6;
//     deal(underlyingAssetAddress, address(this), _amount);

//     uint256 _shares = _deposit(underlyingAsset, vault, _amount, address(this));

//     uint256 _vaultBalanceBefore = yieldVault.convertToAssets(yieldVault.balanceOf(address(vault)));
//     // uint256 _vaultBalanceBefore = vault.convertToAssets(vault.balanceOf(address(address(this))));
//     console2.log("_vaultBalanceBefore", _vaultBalanceBefore);

//     uint256 _aTokenBalanceBefore = aToken.balanceOf(morphoPoolAddress);
//     console2.log("_aTokenBalanceBefore", _aTokenBalanceBefore);

//     console2.log("block.number before", block.number);
//     utils.mineBlocks(drawPeriodSeconds / 12); // Assuming 1 block every 12 seconds
//     console2.log("block.number after", block.number);

//     /**
//      * TODO: finish writing test, the Vault deposit is not accumulating yield.
//      * Looking at the doc, it seems that Morpho tokens are not interest bearing ones.
//      * https://docs.morpho.xyz/start-here/faq#is-there-an-interest-bearing-token-ibtoken
//      */
//     uint256 _vaultBalanceAfter = yieldVault.convertToAssets(yieldVault.balanceOf(address(vault)));
//     // uint256 _vaultBalanceAfter = vault.convertToAssets(vault.balanceOf(address(this)));
//     console2.log("_vaultBalanceAfter", _vaultBalanceAfter);

//     uint256 _aTokenBalanceAfter = aToken.balanceOf(morphoPoolAddress);
//     console2.log("_aTokenBalanceAfter", _aTokenBalanceAfter);
//   }
}
