import * as fs from "fs";
import npmPackage from "../../package.json";

import { Contract, ContractList, VaultInfo, VaultList, Version } from "./types";

const versionSplit = npmPackage.version.split(".");
const patchSplit = versionSplit[2].split("-");

const PACKAGE_VERSION: Version = {
  major: Number(versionSplit[1]),
  minor: Number(versionSplit[0]),
  patch: Number(patchSplit[0]),
};

const ETHEREUM_CHAIN_ID = 1;
const OPTIMISM_CHAIN_ID = 10;

const ETHEREUM_USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const ETHEREUM_WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

const OPTIMISM_USDC_ADDRESS = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607";
const OPTIMISM_WETH_ADDRESS = "0x4200000000000000000000000000000000000006";

const DEFAULT_DECIMALS = 18;
const USDC_DECIMALS = 6;

export const rootFolder = `${__dirname}/../..`;

const getAbi = (type: string) =>
  JSON.parse(fs.readFileSync(`${rootFolder}/out/${type}.sol/${type}.json`, "utf8")).abi;

const getBlob = (path: string) => JSON.parse(fs.readFileSync(`${path}/run-latest.json`, "utf8"));

const getUnderlyingAsset = (chainId: number, underlyingAssetAddress: string) => {
  let name: string;
  let symbol: string;
  let decimals: number;

  if (chainId === ETHEREUM_CHAIN_ID) {
    if (underlyingAssetAddress === ETHEREUM_USDC_ADDRESS) {
      name = "USD Coin";
      symbol = "USDC";
      decimals = USDC_DECIMALS;
    }

    if (underlyingAssetAddress === ETHEREUM_WETH_ADDRESS) {
      name = "Wrapped Ether";
      symbol = "WETH";
      decimals = DEFAULT_DECIMALS;
    }
  }

  if (chainId === OPTIMISM_CHAIN_ID) {
    if (underlyingAssetAddress === OPTIMISM_USDC_ADDRESS) {
      name = "USD Coin";
      symbol = "USDC";
      decimals = USDC_DECIMALS;
    }

    if (underlyingAssetAddress === OPTIMISM_WETH_ADDRESS) {
      name = "Wrapped Ether";
      symbol = "WETH";
      decimals = DEFAULT_DECIMALS;
    }
  }

  return {
    name,
    symbol,
    decimals,
  };
};

const generateVaultInfo = (
  chainId: number,
  address: `0x${string}`,
  deployArguments: string[]
): VaultInfo => {
  const name = deployArguments[1];
  const underlyingAssetAddress = deployArguments[0] as `0x${string}`;
  const underlyingAsset = getUnderlyingAsset(chainId, underlyingAssetAddress);

  return {
    chainId,
    address,
    name,
    decimals: underlyingAsset.decimals,
    symbol: deployArguments[2],
    extensions: {
      underlyingAsset: {
        address: underlyingAssetAddress,
        symbol: underlyingAsset.symbol,
        name: underlyingAsset.name,
      },
    },
  };
};

const formatContract = (
  chainId: number,
  name: string,
  address: `0x${string}`,
  deployArguments: string[]
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
    type,
    abi: getAbi(type),
  };

  if (type === "Vault") {
    return {
      ...defaultContract,
      tokens: [generateVaultInfo(chainId, address, deployArguments)],
    };
  } else {
    return defaultContract;
  }
};

export const generateContractList = (deploymentPaths: string[]): ContractList => {
  const contractList: ContractList = {
    name: "Hyperstructure Mainnet",
    version: PACKAGE_VERSION,
    timestamp: new Date().toISOString(),
    contracts: [],
  };

  // Map to reference deployed contract names by address
  const contractAddressToName = new Map<string, string>();

  deploymentPaths.forEach((deploymentPath) => {
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
        if (contractName) contractAddressToName.set(contractAddress, contractName);

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
          if (contractName === "LiquidationPairFactory") {
            contractName = "LiquidationPair";
          }
        }

        if (transactionType === "CREATE") {
          contractList.contracts.push(
            formatContract(
              chainId,
              contractName,
              contractAddress,
              deployArguments
            )
          );
        }
      }
    );
  });

  return contractList;
};

export const generateVaultList = (
  vaultDeploymentPath: string
): VaultList => {
  const vaultList: VaultList = {
    name: "PoolTogether Mainnet Vault List",
    keywords: ["pooltogether"],
    version: PACKAGE_VERSION,
    timestamp: new Date().toISOString(),
    tokens: [],
  };

  const vaultDeploymentBlob = getBlob(vaultDeploymentPath);
  const chainId = vaultDeploymentBlob.chain;
  const vaultTransactions = vaultDeploymentBlob.transactions;

  vaultTransactions.forEach(
    ({ transactionType, contractName, contractAddress, arguments: deployArguments }) => {
      if (transactionType === "CREATE" && contractName === "VaultMintRate") {
        vaultList.tokens.push(
          generateVaultInfo(chainId, contractAddress, deployArguments)
        );
      }
    }
  );

  return vaultList;
};

export const writeList = (list: ContractList | VaultList, folderName: string, fileName: string) => {
  const dirpath = `${rootFolder}/${folderName}`;

  fs.mkdirSync(dirpath, { recursive: true });
  fs.writeFile(`${dirpath}/${fileName}.json`, JSON.stringify(list), (err) => {
    if (err) {
      console.error(err);
      return;
    }
  });
};
