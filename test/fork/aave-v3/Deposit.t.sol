// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";
import { IERC4626, IERC20 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { ForkAaveV3Setup } from "./ForkAaveV3Setup.t.sol";

contract DepositAaveV3ForkTest is ForkAaveV3Setup {
  /* ============ Tests ============ */
  function testDeposit() external {
    uint256 _amount = 1000e6;
    deal(underlyingAssetAddress, alice, _amount);

    vm.startPrank(alice);

    uint256 _yieldVaultATokenBalanceBefore = aToken.balanceOf(address(yieldVault));
    uint256 _aTokenUnderlyingAssetBalanceBefore = underlyingAsset.balanceOf(address(aToken));
    uint256 _shares = _deposit(underlyingAsset, vault, _amount, alice);

    assertEq(vault.balanceOf(alice), _shares);
    assertEq(vault.convertToAssets(vault.balanceOf(alice)), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(aToken.balanceOf(address(yieldVault)), _yieldVaultATokenBalanceBefore + _amount);
    assertEq(
      underlyingAsset.balanceOf(address(aToken)),
      _aTokenUnderlyingAssetBalanceBefore + _amount
    );

    assertEq(yieldVault.convertToAssets(yieldVault.balanceOf(address(vault))), _amount);

    vm.stopPrank();
  }

  function testSponsor() external {
    uint256 _amount = 1000e6;
    deal(underlyingAssetAddress, alice, _amount);

    vm.startPrank(alice);

    uint256 _yieldVaultATokenBalanceBefore = aToken.balanceOf(address(yieldVault));
    uint256 _aTokenUnderlyingAssetBalanceBefore = underlyingAsset.balanceOf(address(aToken));
    uint256 _shares = _sponsor(underlyingAsset, vault, _amount);

    assertEq(vault.balanceOf(alice), _shares);
    assertEq(vault.convertToAssets(vault.balanceOf(alice)), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(vault.balanceOf(SPONSORSHIP_ADDRESS), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);

    assertEq(aToken.balanceOf(address(yieldVault)), _yieldVaultATokenBalanceBefore + _amount);
    assertEq(
      underlyingAsset.balanceOf(address(aToken)),
      _aTokenUnderlyingAssetBalanceBefore + _amount
    );

    assertEq(yieldVault.convertToAssets(yieldVault.balanceOf(address(vault))), _amount);

    vm.stopPrank();
  }

  function testDelegate() external {
    uint256 _amount = 1000e6;
    deal(underlyingAssetAddress, alice, _amount);

    vm.startPrank(alice);

    uint256 _yieldVaultATokenBalanceBefore = aToken.balanceOf(address(yieldVault));
    uint256 _aTokenUnderlyingAssetBalanceBefore = underlyingAsset.balanceOf(address(aToken));
    uint256 _shares = _deposit(underlyingAsset, vault, _amount, alice);

    twabController.delegate(address(vault), bob);

    assertEq(vault.balanceOf(alice), _shares);
    assertEq(vault.convertToAssets(vault.balanceOf(alice)), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _amount);

    assertEq(aToken.balanceOf(address(yieldVault)), _yieldVaultATokenBalanceBefore + _amount);
    assertEq(
      underlyingAsset.balanceOf(address(aToken)),
      _aTokenUnderlyingAssetBalanceBefore + _amount
    );

    assertEq(yieldVault.convertToAssets(yieldVault.balanceOf(address(vault))), _amount);

    vm.stopPrank();
  }
}
