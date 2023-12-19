// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { TwabController } from "pt-v5-twab-controller/TwabController.sol";
import { TwabRewards } from "pt-v5-twab-rewards/TwabRewards.sol";

import { ScriptHelpers } from "../helpers/ScriptHelpers.sol";

contract DeployTwabRewards is ScriptHelpers {
  function run() public {
    vm.startBroadcast();
    new TwabRewards(_getTwabController());
    vm.stopBroadcast();
  }
}
