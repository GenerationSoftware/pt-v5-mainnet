import {
  generateContractList,
  generateVaultList,
  rootFolder,
  writeList,
} from "../helpers/generateContractList";

const stableTokenDeploymentPath = `${rootFolder}/broadcast/DeployStableToken.s.sol/31337`;
const tokenDeploymentPath = `${rootFolder}/broadcast/DeployToken.s.sol/31337`;
const vaultDeploymentPath = `${rootFolder}/broadcast/DeployVault.s.sol/31337`;

const deploymentPaths = [
  stableTokenDeploymentPath,
  tokenDeploymentPath,
  `${rootFolder}/broadcast/DeployPool.s.sol/31337`,
  `${rootFolder}/broadcast/DeployYieldVault.s.sol/31337`,
  vaultDeploymentPath,
];

writeList(generateContractList(deploymentPaths), "deployments/local", "contracts");
writeList(
  generateVaultList(vaultDeploymentPath),
  "deployments/local",
  "vaults"
);
