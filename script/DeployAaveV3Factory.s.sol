// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ScriptBase } from "./ScriptBase.sol";
// import { AaveV3Optimism } from "aave-address-book/AaveV3Optimism.sol";
import { AaveV3ERC4626Factory, IPool, IRewardsController } from "yield-daddy/aave-v3/AaveV3ERC4626Factory.sol";

contract DeployAaveV3Factory is ScriptBase {
  function run() public {
    vm.startBroadcast();

      // new AaveV3ERC4626Factory(
      //   IPool(address(AaveV3Optimism.POOL)),
      //   0x75620e4F65BC029a2DA032F470ebA779087c7918, // Gnosis Safe Reward recipient,
      //   IRewardsController(address(AaveV3Optimism.DEFAULT_INCENTIVES_CONTROLLER))
      // );

    vm.stopBroadcast();
  }
}
