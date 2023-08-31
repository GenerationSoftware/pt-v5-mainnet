import * as fs from "fs";
import { ethers } from "ethers";
import npmPackage from "../../package.json";

import { Contract, ContractList, VaultInfo, VaultList, Version } from "./types";

const { Interface } = ethers;

const versionSplit = npmPackage.version.split(".");
const patchSplit = versionSplit[2].split("-");

const PACKAGE_VERSION: Version = {
  major: Number(versionSplit[0]),
  minor: Number(versionSplit[1]), // Beta version
  patch: Number(patchSplit[0]),
};

const ETHEREUM_CHAIN_ID = 1;
const OPTIMISM_CHAIN_ID = 10;

const ETHEREUM_POOL_ADDRESS = "0x0cEC1A9154Ff802e7934Fc916Ed7Ca50bDE6844e";
const ETHEREUM_USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const ETHEREUM_WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

const OPTIMISM_POOL_ADDRESS = "0x395Ae52bB17aef68C2888d941736A71dC6d4e125";
const OPTIMISM_USDC_ADDRESS = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607";
const OPTIMISM_WETH_ADDRESS = "0x4200000000000000000000000000000000000006";

const DEFAULT_DECIMALS = 18;
const USDC_DECIMALS = 6;

const aaveV3YieldVaultFactoryDeployData = {
  [OPTIMISM_USDC_ADDRESS]:
    "0xabeccaa40000000000000000000000007f5c764cbc14f9669b88837ca1490cca17c31607",
  [OPTIMISM_WETH_ADDRESS]:
    "0xabeccaa40000000000000000000000004200000000000000000000000000000000000006",
};

const vaultFactoryDeployData = {
  [OPTIMISM_USDC_ADDRESS]:
    "0xbfc49da30000000000000000000000007f5c764cbc14f9669b88837ca1490cca17c31607000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000dcd989ca22e51035e1bdba936a980546f89d40dc0000000000000000000000000bfa9c73aec9f57ad8e5b6f67125e9e8a6c060a600000000000000000000000008e2fad7d06f14136a7b6854ee54b4c6a60c5b330000000000000000000000008537c5a9aad3ec1d31a84e94d19fcfc681e83ed0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a791e828fdd420fbe16416efdf509e4b9088dd40000000000000000000000000000000000000000000000000000000000000021506f6f6c546f6765746865722055534420436f696e205072697a6520546f6b656e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000075054555344435400000000000000000000000000000000000000000000000000",
  [OPTIMISM_WETH_ADDRESS]:
    "0xbfc49da30000000000000000000000004200000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000dcd989ca22e51035e1bdba936a980546f89d40dc000000000000000000000000ea325c4a2e619d3b2ba37dca7705c5f8da0b8eee00000000000000000000000008e2fad7d06f14136a7b6854ee54b4c6a60c5b330000000000000000000000008537c5a9aad3ec1d31a84e94d19fcfc681e83ed0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a791e828fdd420fbe16416efdf509e4b9088dd40000000000000000000000000000000000000000000000000000000000000026506f6f6c546f6765746865722057726170706564204574686572205072697a6520546f6b656e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000075054574554485400000000000000000000000000000000000000000000000000",
};

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
  underlyingAssetAddress: `0x${string}`,
  name: string,
  symbol: string
): VaultInfo => {
  const underlyingAsset = getUnderlyingAsset(chainId, underlyingAssetAddress);

  return {
    chainId,
    address,
    name,
    decimals: underlyingAsset.decimals,
    symbol,
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
  transactionData: any
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
    const { underlyingAssetAddress, name, symbol } = getVaultInfos(transactionData);

    return {
      ...defaultContract,
      tokens: [generateVaultInfo(chainId, address, underlyingAssetAddress, name, symbol)],
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
        transaction,
        additionalContracts,
      }) => {
        const createdContract = additionalContracts[0];

        // Store name of contract for reference later
        if (contractName) contractAddressToName.set(contractAddress, contractName);

        if (transactionType == "CALL") {
          // If `createdContract` is not empty, it means that a contract was created
          if (createdContract) {
            // Handle case when contract name isn't available on CALL
            if (!contractName) {
              const storedName = contractAddressToName.get(contractAddress);
              if (storedName) contractName = storedName;
            }

            if (createdContract.transactionType === "CREATE2") {
              Object.keys(aaveV3YieldVaultFactoryDeployData).forEach((key) => {
                if (transaction.data === aaveV3YieldVaultFactoryDeployData[key]) {
                  contractName = "AaveV3ERC4626";
                }
              });

              Object.keys(vaultFactoryDeployData).forEach((key) => {
                if (transaction.data === vaultFactoryDeployData[key]) {
                  contractName = "Vault";
                }
              });
            }

            if (contractName === "LiquidationPairFactory") {
              contractName = "LiquidationPair";
            }

            contractAddress = createdContract.address;
            transactionType = "CREATE";
          }
        }

        if (transactionType === "CREATE") {
          contractList.contracts.push(
            formatContract(chainId, contractName, contractAddress, transaction.data)
          );
        }
      }
    );
  });

  return contractList;
};

export const getVaultInfos = (transactionData: any) => {
  let underlyingAssetAddress: `0x${string}`;
  let name: string;
  let symbol: string;

  if (transactionData === vaultFactoryDeployData[OPTIMISM_USDC_ADDRESS]) {
    underlyingAssetAddress = OPTIMISM_USDC_ADDRESS;
    name = "PoolTogether USD Coin Prize Token";
    symbol = "PTUSDCT";
  }

  if (transactionData === vaultFactoryDeployData[OPTIMISM_WETH_ADDRESS]) {
    underlyingAssetAddress = OPTIMISM_WETH_ADDRESS;
    name = "PoolTogether Wrapped Ether Prize Token";
    symbol = "PTWETHT";
  }

  return { underlyingAssetAddress, name, symbol };
}

export const generateVaultList = (vaultDeploymentPath: string): VaultList => {
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
    ({ transactionType, contractName, transaction, additionalContracts }) => {
      if (transactionType === "CALL") {
        const createdContract = additionalContracts[0];

        if (createdContract && createdContract.transactionType === "CREATE2") {

          const { underlyingAssetAddress, name, symbol } = getVaultInfos(transaction.data);

          vaultList.tokens.push(
            generateVaultInfo(
              chainId,
              createdContract.address,
              underlyingAssetAddress,
              name,
              symbol
            )
          );
        }
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
