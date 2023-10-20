// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import { AaveV3Optimism } from "aave-address-book/AaveV3Optimism.sol";
import { AaveV3ERC4626 } from "yield-daddy/aave-v3/AaveV3ERC4626.sol";
import { AaveV3ERC4626Factory, ERC20, ERC4626, IPool, IRewardsController } from "yield-daddy/aave-v3/AaveV3ERC4626Factory.sol";
import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { ForkBaseSetup } from "test/utils/ForkBaseSetup.t.sol";

contract ForkAaveV3Setup is ForkBaseSetup {
  IERC4626 public yieldVault;
  ERC20 public aToken;
  address public aaveLendingPoolAddress;

  /* ============ setUp ============ */
  function setUp() public {
    uint256 optimismFork = vm.createFork(vm.rpcUrl("optimism"));
    vm.selectFork(optimismFork);

    AaveV3ERC4626Factory _aaveV3Factory = new AaveV3ERC4626Factory(
      IPool(address(AaveV3Optimism.POOL)),
      G9_TEAM_OPTIMISM_ADDRESS, // Reward recipient,
      IRewardsController(address(AaveV3Optimism.DEFAULT_INCENTIVES_CONTROLLER))
    );

    ERC4626 _yieldVault = _aaveV3Factory.createERC4626(ERC20(_getToken("USDC")));

    yieldVault = IERC4626(address(_yieldVault));
    aToken = AaveV3ERC4626(address(_yieldVault)).aToken();
    aaveLendingPoolAddress = address(AaveV3ERC4626(address(_yieldVault)).lendingPool());

    forkSetUp(yieldVault);
  }
}
