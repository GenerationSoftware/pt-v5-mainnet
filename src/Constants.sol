// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

abstract contract Constants {
  // Addresses
  // Defender
  address internal constant ETHEREUM_DEFENDER_ADDRESS = 0xA2A8BccD38138f1169ADdb0f3df9236a3CCCd753;
  address internal constant OPTIMISM_DEFENDER_ADDRESS = 0xCeA11E14067697C085e1142afd2540b23f18304D;

  // MessageExecutor
  address internal constant ERC5164_EXECUTOR_OPTIMISM = 0x890a87E71E731342a6d10e7628bd1F0733ce3296;

  // Multisigs
  address internal constant EXECUTIVE_TEAM_OPTIMISM_ADDRESS =
    0x8d352083F7094dc51Cd7dA8c5C0985AD6e149629;

  // Chain IDs
  uint256 internal constant ETHEREUM_CHAIN_ID = 1;
  uint256 internal constant OPTIMISM_CHAIN_ID = 10;

  // Deploy parameters
  // Chainlink VRF
  uint32 internal constant CHAINLINK_CALLBACK_GAS_LIMIT = 1_000_000;
  uint16 internal constant CHAINLINK_REQUEST_CONFIRMATIONS = 3;

  // Claimer
  uint256 internal constant CLAIMER_MIN_FEE = 0.0001e18;
  uint256 internal constant CLAIMER_MAX_FEE = 1000e18;

  // Prize Pool
  uint8 internal constant TIER_SHARES = 100;
  uint8 internal constant RESERVE_SHARES = 100;
  uint24 internal constant GRAND_PRIZE_PERIOD_DRAWS = 12;
  uint32 internal constant DRAW_PERIOD_SECONDS = 4 hours;
  uint256 internal constant MIN_TIME_AHEAD = DRAW_PERIOD_SECONDS;

  // RngAuctions
  // two auctions should end at the latest halfway through the draw period
  uint64 internal constant AUCTION_DURATION = DRAW_PERIOD_SECONDS / 4;
  uint64 internal constant AUCTION_TARGET_SALE_TIME = AUCTION_DURATION / 4;

  // Twab
  // nice round fraction of the draw period
  uint32 internal constant TWAB_PERIOD_LENGTH = 1 hours;

  // Timestamps
  uint256 internal constant ONE_YEAR_IN_SECONDS = 31557600;

  // Tokens addresses
  address internal constant ETHEREUM_POOL_ADDRESS = 0x0cEC1A9154Ff802e7934Fc916Ed7Ca50bDE6844e;
  address internal constant ETHEREUM_USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address internal constant ETHEREUM_WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  address internal constant OPTIMISM_POOL_ADDRESS = 0x395Ae52bB17aef68C2888d941736A71dC6d4e125;
  address internal constant OPTIMISM_USDC_ADDRESS = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
  address internal constant OPTIMISM_WETH_ADDRESS = 0x4200000000000000000000000000000000000006;

  // Tokens decimals
  uint8 internal constant DEFAULT_TOKEN_DECIMAL = 18;
  uint8 internal constant USDC_TOKEN_DECIMAL = 6;

  // Token prices
  uint256 internal constant USDC_PRICE = 100000000;
  uint256 internal constant POOL_PRICE = 100000000;
  uint256 internal constant ETH_PRICE = 166876925050;
  uint256 internal constant PRIZE_TOKEN_PRICE = 1e18;

  function _matches(string memory a, string memory b) internal pure returns (bool) {
    return keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b)));
  }

  function _getToken(string memory _tokenSymbol) internal view returns (address) {
    address _tokenAddress;

    if (block.chainid == ETHEREUM_CHAIN_ID) {
      if (_matches(_tokenSymbol, "POOL")) {
        _tokenAddress = ETHEREUM_POOL_ADDRESS;
      }

      if (_matches(_tokenSymbol, "USDC")) {
        _tokenAddress = ETHEREUM_USDC_ADDRESS;
      }

      if (_matches(_tokenSymbol, "WETH")) {
        _tokenAddress = ETHEREUM_WETH_ADDRESS;
      }
    } else if (block.chainid == OPTIMISM_CHAIN_ID) {
      if (_matches(_tokenSymbol, "POOL")) {
        _tokenAddress = OPTIMISM_POOL_ADDRESS;
      }

      if (_matches(_tokenSymbol, "USDC")) {
        _tokenAddress = OPTIMISM_USDC_ADDRESS;
      }

      if (_matches(_tokenSymbol, "WETH")) {
        _tokenAddress = OPTIMISM_WETH_ADDRESS;
      }
    }

    return _tokenAddress;
  }
}
