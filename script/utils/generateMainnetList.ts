import {
  generateContractList,
  generateVaultList,
  rootFolder,
  writeList,
} from "../helpers/generateContractList";

const vaultDeploymentPath = `${rootFolder}/broadcast/DeployVault.s.sol/10`;

const mainnetDeploymentPaths = [`${rootFolder}/broadcast/DeployL1RngAuction.s.sol/1`];

const optimismDeploymentPaths = [
  `${rootFolder}/broadcast/DeployAaveV3Factory.s.sol/10`,
  `${rootFolder}/broadcast/DeployAaveV3YieldVault.s.sol/10`,
  `${rootFolder}/broadcast/DeployL2PrizePool.s.sol/10`,
  `${rootFolder}/broadcast/DeployTwabDelegator.s.sol/10`,
  `${rootFolder}/broadcast/DeployTwabRewards.s.sol/10`,
  vaultDeploymentPath,
];

writeList(generateContractList(mainnetDeploymentPaths), "deployments/ethereum", "contracts");
writeList(generateContractList(optimismDeploymentPaths), "deployments/optimism", "contracts");
writeList(generateVaultList(vaultDeploymentPath), "deployments/optimism", "vaults");
