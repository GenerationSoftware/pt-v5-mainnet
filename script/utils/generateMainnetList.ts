import {
  generateContractList,
  generateVaultList,
  rootFolder,
  writeList,
} from "../helpers/generateContractList";

const ethereumDeploymentPaths = [`${rootFolder}/broadcast/DeployL1RngAuction.s.sol/1`];
writeList(generateContractList(ethereumDeploymentPaths), "deployments/ethereum", "contracts");

// const ethereumVaultDeploymentPath = `${rootFolder}/broadcast/DeployVault.s.sol/1`;

// const ethereumDeploymentPaths = [
//   `${rootFolder}/broadcast/DeployPool.s.sol/1`,
//   `${rootFolder}/broadcast/DeployYieldVault.s.sol/1`,
//   ethereumVaultDeploymentPath,
// ];

// writeList(generateContractList(ethereumDeploymentPaths), "deployments/ethereum", "contracts");
// writeList(
//   generateVaultList(ethereumVaultDeploymentPath),
//   "deployments/ethereum",
//   "vaults"
// );

const optimismVaultDeploymentPath = `${rootFolder}/broadcast/DeployVault.s.sol/10`;

const optimismDeploymentPaths = [
  `${rootFolder}/broadcast/DeployL2PrizePool.s.sol/10`,
  `${rootFolder}/broadcast/DeployYieldVault.s.sol/10`,
  optimismVaultDeploymentPath,
];

writeList(
  generateContractList(optimismDeploymentPaths),
  "deployments/optimism",
  "contracts"
);
writeList(
  generateVaultList(optimismVaultDeploymentPath),
  "deployments/optimism",
  "vaults"
);
