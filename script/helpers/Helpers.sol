// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { strings } from "solidity-stringutils/strings.sol";
import { Strings } from "openzeppelin/utils/Strings.sol";

import { Claimer } from "pt-v5-claimer/Claimer.sol";
import { LiquidationPairFactory } from "pt-v5-cgda-liquidator/LiquidationPairFactory.sol";
import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";
import { RngAuctionRelayer } from "pt-v5-draw-auction/abstract/RngAuctionRelayer.sol";

import { ERC20Mintable } from "../../src/ERC20Mintable.sol";
import { MarketRate } from "../../src/MarketRate.sol";
import { TokenFaucet } from "../../src/TokenFaucet.sol";
import { VaultMintRate } from "../../src/VaultMintRate.sol";
import { YieldVaultMintRate } from "../../src/YieldVaultMintRate.sol";

import { LinkTokenInterface } from "chainlink/interfaces/LinkTokenInterface.sol";
import { VRFV2WrapperInterface } from "chainlink/interfaces/VRFV2WrapperInterface.sol";

// Testnet deployment paths
uint256 constant ETHEREUM_CHAIN_ID = 1;
uint256 constant OPTIMISM_CHAIN_ID = 10;
string constant ETHEREUM_PATH = "broadcast/Deploy.s.sol/1/";
string constant OPTIMISM_PATH = "broadcast/Deploy.s.sol/10/";
string constant LOCAL_PATH = "/broadcast/Deploy.s.sol/31337";

abstract contract Helpers is Script {
  using strings for *;
  using stdJson for string;

  /* ============ Constants ============ */
  uint8 internal constant DEFAULT_TOKEN_DECIMAL = 18;
  uint8 internal constant USDC_TOKEN_DECIMAL = 6;

  uint256 internal constant USDC_PRICE = 100000000;
  uint256 internal constant POOL_PRICE = 100000000;
  uint256 internal constant ETH_PRICE = 166876925050;
  uint256 internal constant PRIZE_TOKEN_PRICE = 1e18;

  uint256 internal constant ONE_YEAR_IN_SECONDS = 31557600;

  address internal constant ETHEREUM_DEFENDER_ADDRESS = 0xA2A8BccD38138f1169ADdb0f3df9236a3CCCd753;
  address internal constant OPTIMISM_DEFENDER_ADDRESS =
    0xCeA11E14067697C085e1142afd2540b23f18304D;

  string internal DEPLOY_POOL_SCRIPT;

  constructor() {
    DEPLOY_POOL_SCRIPT = block.chainid == OPTIMISM_CHAIN_ID
      ? "DeployL2PrizePool.s.sol"
      : "DeployPool.s.sol";
  }

  /* ============ Helpers ============ */

  function _toDecimals(uint256 _amount, uint8 _decimals) internal pure returns (uint256) {
    return _amount * (10 ** _decimals);
  }

  /**
   * @notice Get exchange rate for liquidation pair `virtualReserveOut`.
   * @param _tokenPrice Price of the token represented in 8 decimals
   * @param _decimalOffset Offset between the prize token decimals and the token decimals
   */
  function _getExchangeRate(
    uint256 _tokenPrice,
    uint8 _decimalOffset
  ) internal pure returns (uint128) {
    return uint128((PRIZE_TOKEN_PRICE * 1e8) / (_tokenPrice * (10 ** _decimalOffset)));
  }

  function _getDeploymentArtifacts(
    string memory _deploymentArtifactsPath
  ) internal returns (string[] memory) {
    string[] memory inputs = new string[](4);
    inputs[0] = "ls";
    inputs[1] = "-m";
    inputs[2] = "-r";
    inputs[3] = string.concat(vm.projectRoot(), _deploymentArtifactsPath);
    bytes memory res = vm.ffi(inputs);

    // Slice ls result
    strings.slice memory s = string(res).toSlice();

    // Remove directory jargon at the beginning of the slice (Fix for Windows Git Bash)
    strings.slice memory dirEnd = "/:".toSlice();
    strings.slice memory sWithoutDirPrefix = s.copy().find(dirEnd).beyond(dirEnd);
    if (!sWithoutDirPrefix.empty()) s = sWithoutDirPrefix;

    // Remove newline and push into array
    strings.slice memory delim = ", ".toSlice();
    strings.slice memory sliceNewline = "\n".toSlice();
    string[] memory filesName = new string[](s.count(delim) + 1);

    for (uint256 i = 0; i < filesName.length; i++) {
      filesName[i] = s.split(delim).beyond(sliceNewline).toString();
    }

    return filesName;
  }

  function _getContractAddress(
    string memory _contractName,
    string memory _artifactsPath,
    string memory _errorMsg
  ) internal returns (address) {
    string[] memory filesName = _getDeploymentArtifacts(_artifactsPath);
    uint256 filesNameLength = filesName.length;

    // Loop through deployment artifacts and find latest deployed `_contractName` address
    for (uint256 i; i < filesNameLength; i++) {
      string memory filePath = string.concat(vm.projectRoot(), _artifactsPath, filesName[i]);
      string memory jsonFile = vm.readFile(filePath);
      bytes[] memory rawTxs = abi.decode(vm.parseJson(jsonFile, ".transactions"), (bytes[]));

      uint256 transactionsLength = rawTxs.length;

      for (uint256 j; j < transactionsLength; j++) {
        string memory contractName = abi.decode(
          stdJson.parseRaw(
            jsonFile,
            string.concat(".transactions[", vm.toString(j), "].contractName")
          ),
          (string)
        );

        if (
          keccak256(abi.encodePacked((contractName))) ==
          keccak256(abi.encodePacked((_contractName)))
        ) {
          address contractAddress = abi.decode(
            stdJson.parseRaw(
              jsonFile,
              string.concat(".transactions[", vm.toString(j), "].contractAddress")
            ),
            (address)
          );

          return contractAddress;
        }
      }
    }

    revert(_errorMsg);
  }

  function _getTokenAddress(
    string memory _contractName,
    string memory _tokenSymbol,
    uint256 _argumentPosition,
    string memory _artifactsPath,
    string memory _errorMsg
  ) internal returns (address) {
    string[] memory filesName = _getDeploymentArtifacts(_artifactsPath);

    // Loop through deployment artifacts and find latest deployed `_contractName` address
    for (uint256 i; i < filesName.length; i++) {
      string memory jsonFile = vm.readFile(
        string.concat(vm.projectRoot(), _artifactsPath, filesName[i])
      );
      bytes[] memory rawTxs = abi.decode(vm.parseJson(jsonFile, ".transactions"), (bytes[]));

      for (uint256 j; j < rawTxs.length; j++) {
        string memory index = vm.toString(j);

        string memory _argumentPositionString = vm.toString(_argumentPosition);

        if (
          _matches(
            abi.decode(
              stdJson.parseRaw(
                jsonFile,
                string.concat(".transactions[", index, "].transactionType")
              ),
              (string)
            ),
            "CREATE"
          ) &&
          _matches(
            abi.decode(
              stdJson.parseRaw(jsonFile, string.concat(".transactions[", index, "].contractName")),
              (string)
            ),
            _contractName
          ) &&
          _matches(
            abi.decode(
              stdJson.parseRaw(
                jsonFile,
                string.concat(".transactions[", index, "].arguments[", _argumentPositionString, "]")
              ),
              (string)
            ),
            _tokenSymbol
          )
        ) {
          return
            abi.decode(
              stdJson.parseRaw(
                jsonFile,
                string.concat(".transactions[", index, "].contractAddress")
              ),
              (address)
            );
        }
      }
    }

    revert(_errorMsg);
  }

  function _matches(string memory a, string memory b) internal pure returns (bool) {
    return keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b)));
  }

  function _getDeployPath(string memory _deployPath) internal view returns (string memory) {
    return _getDeployPathWithChainId(_deployPath, block.chainid);
  }

  function _getDeployPathWithChainId(
    string memory _deployPath,
    uint256 chainId
  ) internal pure returns (string memory) {
    return string.concat("/broadcast/", _deployPath, "/", Strings.toString(chainId), "/");
  }

  /* ============ Getters ============ */

  function _getClaimer() internal returns (Claimer) {
    return
      Claimer(
        _getContractAddress("Claimer", _getDeployPath(DEPLOY_POOL_SCRIPT), "claimer-not-found")
      );
  }

  function _getL1RngAuctionRelayerRemote() internal returns (RngAuctionRelayer) {
    return
      RngAuctionRelayer(
        _getContractAddress(
          "RngAuctionRelayerRemoteOwner",
          _getDeployPathWithChainId("DeployL1RngAuction.s.sol", ETHEREUM_CHAIN_ID),
          "rng-auction-relayer-not-found"
        )
      );
  }

  function _getLiquidationPairFactory() internal returns (LiquidationPairFactory) {
    return
      LiquidationPairFactory(
        _getContractAddress(
          "LiquidationPairFactory",
          _getDeployPath(DEPLOY_POOL_SCRIPT),
          "liquidation-pair-factory-not-found"
        )
      );
  }

  function _getPrizePool() internal returns (PrizePool) {
    return
      PrizePool(
        _getContractAddress("PrizePool", _getDeployPath(DEPLOY_POOL_SCRIPT), "prize-pool-not-found")
      );
  }

  function _getTwabController() internal returns (TwabController) {
    return
      TwabController(
        _getContractAddress(
          "TwabController",
          _getDeployPath(DEPLOY_POOL_SCRIPT),
          "twab-controller-not-found"
        )
      );
  }

  function _getToken(
    string memory _tokenSymbol
  ) internal returns (ERC20) {
    if (block.chainid == ETHEREUM_CHAIN_ID) {
      if (_matches(_tokenSymbol, "USDC")) {
        return ERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
      }

      if (_matches(_tokenSymbol, "WETH")) {
        return ERC20(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
      }
    }

    if (block.chainid == OPTIMISM_CHAIN_ID) {
      if (_matches(_tokenSymbol, "USDC")) {
        return ERC20(address(0x7F5c764cBc14f9669B88837ca1490cCa17c31607));
      }

      if (_matches(_tokenSymbol, "WETH")) {
        return ERC20(address(0x4200000000000000000000000000000000000006));
      }
    }
  }

  function _getVault(string memory _tokenSymbol) internal returns (VaultMint) {
    string memory deployPath = _getDeployPath("DeployVault.s.sol");
    address tokenAddress = _getTokenAddress(
      "Vault",
      _tokenSymbol,
      2,
      deployPath,
      "vault-not-found"
    );
    return Vault(tokenAddress);
  }

  function _getYieldVault(string memory _tokenSymbol) internal returns (YieldVaultMintRate) {
    string memory deployPath = _getDeployPath("DeployYieldVault.s.sol");
    address tokenAddress = _getTokenAddress(
      "YieldVaultMintRate",
      _tokenSymbol,
      2,
      deployPath,
      "yield-vault-not-found"
    );
    return YieldVaultMintRate(tokenAddress);
  }

  function _getLinkToken() internal view returns (LinkTokenInterface) {
    if (block.chainid == ETHEREUM_CHAIN_ID) {
      return LinkTokenInterface(address(0x514910771AF9Ca656af840dff83E8264EcF986CA));
    } else {
      revert("Link token address not set in `_getLinkToken` for this chain.");
    }
  }

  function _getVrfV2Wrapper() internal view returns (VRFV2WrapperInterface) {
    if (block.chainid == ETHEREUM_CHAIN_ID) {
      return VRFV2WrapperInterface(address(0x5A861794B927983406fCE1D062e00b9368d97Df6));
    } else {
      revert("VRF V2 Wrapper address not set in `_getVrfV2Wrapper` for this chain.");
    }
  }
}
