import * as fs from "fs";
import npmPackage from "../../package.json";

import { Contract, ContractList, VaultInfo, VaultList, Version } from "./types";

const versionSplit = npmPackage.version.split(".");
const patchSplit = versionSplit[2].split("-");

const PACKAGE_VERSION: Version = {
  major: Number(versionSplit[0]),
  minor: Number(versionSplit[1]),
  patch: Number(patchSplit[0]),
};

export const rootFolder = `${__dirname}/../..`;

const renameType = (type: string) => {
  switch (type) {
    case "YieldVaultMintRate":
      return "YieldVault";
    case "PrizeVaultMintRate":
      return "PrizeVault";
    default:
      return type;
  }
};

const getAbi = (type: string) =>
  JSON.parse(
    fs.readFileSync(`${rootFolder}/out/${type}.sol/${type}.json`, "utf8")
  ).abi;

const getBlob = (path: string) =>
  JSON.parse(fs.readFileSync(`${path}/run-latest.json`, "utf8"));

const formatContract = (
  chainId: number,
  name: string,
  address: `0x${string}`,
): Contract => {
  const regex = /V[1-9+]((.{0,2}[0-9+]){0,2})$/g;
  const version = name.match(regex)?.[0]?.slice(1).split(".") || [1, 0, 0];
  const type = name.split(regex)[0];

  const defaultContract = {
    chainId,
    address,
    version: {
      major: Number(version[0]),
      minor: Number(version[1]) || 0,
      patch: Number(version[2]) || 0,
    },
    type: renameType(type),
    abi: getAbi(type),
  };

  return defaultContract;
};

export const generateContractList = (
  deploymentPaths: string[]
): ContractList => {
  const contractList: ContractList = {
    name: "PoolTogether V5",
    version: PACKAGE_VERSION,
    timestamp: new Date().toISOString(),
    contracts: [],
  };

  // Map to reference deployed contract names by address
  const contractAddressToName = new Map<string, string>();

  for (let i = 0; i < deploymentPaths.length; i++) {
    const deploymentPath = deploymentPaths[i];
    if (!fs.existsSync(deploymentPath)) {
      console.log("Skipping path", deploymentPath);
      continue;
    };
    const deploymentBlob = getBlob(deploymentPath);
    const chainId = deploymentBlob.chain;
    const transactions = deploymentBlob.transactions;

    transactions.forEach(
      ({
        transactionType,
        contractName,
        contractAddress,
        arguments: deployArguments,
        additionalContracts,
      }) => {
        const createdContract = additionalContracts[0];

        // Store name of contract for reference later
        if (contractName)
          contractAddressToName.set(contractAddress, contractName);

        if (
          transactionType == "CALL" &&
          createdContract &&
          createdContract.transactionType === "CREATE"
        ) {
          // Handle case when contract name isn't available on CALL
          if (!contractName) {
            const storedName = contractAddressToName.get(contractAddress);
            if (storedName) contractName = storedName;
          }

          // Set contract info to the created contract
          transactionType = "CREATE";
          contractAddress = createdContract.address;
          if (contractName.endsWith("TpdaLiquidationPairFactory")) {
            contractName = "TpdaLiquidationPair";
          } else if (contractName.endsWith("ClaimerFactory")) {
            contractName = "Claimer";
          }
        }

        if (transactionType === "CREATE") {
          contractList.contracts.push(
            formatContract(
              chainId,
              contractName,
              contractAddress
            )
          );
        }
      }
    );
  };

  return contractList;
};

export const findConstructorArguments = (deploymentPaths: string[], targetContractAddress: string): string[] => {
  let result: string[];

  for (let d = 0; d < deploymentPaths.length; d++) {
    const deploymentPath = deploymentPaths[d];
    const deploymentBlob = getBlob(deploymentPath);
    const transactions = deploymentBlob.transactions;

    for (let i = 0; i < transactions.length; i++) {
      const {
        transactionType,
        contractAddress,
        arguments: deployArguments,
        additionalContracts,
      } = transactions[i];
      if (contractAddress === targetContractAddress) {
        result = deployArguments;
        break;
      }
      if (
        transactionType == "CALL" &&
        additionalContracts.length > 0 &&
        additionalContracts[0].address === targetContractAddress
      ) {
        result = deployArguments;
        break;
      }
    }
  }

  return result;
};

export const generateVaultList = (
  deploymentPaths: string[],
  contractList: ContractList
): VaultList => {
  const vaultList: VaultList = {
    name: "PoolTogether V5 Vault List",
    keywords: ["pooltogether"],
    version: PACKAGE_VERSION,
    timestamp: new Date().toISOString(),
    tokens: [],
  };

  contractList.contracts.filter((contract) => contract.type === "PrizeVault").forEach((contract) => {
    const args = findConstructorArguments(deploymentPaths, contract.address);
    const yieldVaultAddress = args[2];
    const assetAddress = findConstructorArguments(deploymentPaths, yieldVaultAddress)[0];
    const assetArguments = findConstructorArguments(deploymentPaths, assetAddress);
    vaultList.tokens.push({
      chainId: contract.chainId,
      address: contract.address,
      name: stripQuotes(args[0]),
      decimals: parseInt(assetArguments[2]),
      symbol: stripQuotes(args[1]),
      extensions: {
        underlyingAsset: {
          address: assetAddress,
          symbol: stripQuotes(assetArguments[1]),
          name: stripQuotes(assetArguments[0])
        }
      }
    });
  })

  return vaultList;
};

export const writeList = (
  list: ContractList | VaultList,
  folderName: string,
  fileName: string
) => {
  const dirpath = `${rootFolder}/${folderName}`;

  fs.mkdirSync(dirpath, { recursive: true });
  fs.writeFile(`${dirpath}/${fileName}.json`, JSON.stringify(list, null, 2), (err) => {
    if (err) {
      console.error(err);
      return;
    }
  });
};

function stripQuotes(str) {
  return str.replace(/['"]+/g, '');
}


export function getDeploymentPaths(chainId: number) {
  return [
    `${rootFolder}/broadcast/DeployPrizePool.s.sol/${chainId}`,
    `${rootFolder}/broadcast/DeployAaveV3Factory.s.sol/${chainId}`,
  ];
}

export function writeFiles(chainId: number, chainName: string) {
  const deploymentPaths = getDeploymentPaths(chainId);

  if (!fs.existsSync(deploymentPaths[0])) {
    console.error(`No files for chainId ${chainId} and chainName ${chainName}`)
    return;
  }

  const contractList = generateContractList(deploymentPaths);

  writeList(
    contractList,
    `deployments/${chainName}`,
    `contracts`
  );
  
  writeList(
    generateVaultList(
      deploymentPaths,
      contractList
    ),
    `deployments/${chainName}`,
    `vaults`
  );
}
