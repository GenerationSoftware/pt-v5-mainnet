# PoolTogether V5 Mainnet

PoolTogether V5 Mainnet deployment scripts.

## Getting started

Clone the repository:

```
git clone https://github.com/GenerationSoftware/pt-v5-mainnet.git
```

## Development

### Installation

You may have to install the following tools to use this repository:

- [Foundry](https://github.com/foundry-rs/foundry) to compile and test contracts
- [direnv](https://direnv.net/) to handle environment variables
- [lcov](https://github.com/linux-test-project/lcov) to generate the code coverage report

Install dependencies:

```
npm i
```

### Env

Copy `.envrc.example` and write down the env variables needed to run this project.

```
cp .envrc.example .envrc
```

Once your env variables are setup, load them with:

```
direnv allow
```

### Compile

Run the following command to compile the contracts:

```
npm run compile
```

### Coverage

Forge is used for coverage, run it with:

```
npm run coverage
```

You can then consult the report by opening `coverage/index.html`:

```
open coverage/index.html
```

### Code quality

[Husky](https://typicode.github.io/husky/#/) is used to run [lint-staged](https://github.com/okonet/lint-staged) and tests when committing.

[Prettier](https://prettier.io) is used to format TypeScript and Solidity code. Use it by running:

```
npm run format
```

[Solhint](https://protofire.github.io/solhint/) is used to lint Solidity files. Run it with:

```
npm run hint
```

### CI

A default Github Actions workflow is setup to execute on push and pull request.

It will build the contracts and run the test coverage.

You can modify it here: [.github/workflows/coverage.yml](.github/workflows/coverage.yml)

For the coverage to work, you will need to setup the `MAINNET_RPC_URL` repository secret in the settings of your Github repository.

## Deployment

First setup npm:

```
nvm use
npm i
```

### Local

ATTENTION: Since the local deployment is using fork tests, it will store deployment artifacts in the same `./broadcast` folders than the mainnet deployment.

Start Ethereum mainnet fork:

`npm run anvil:ethereum:local`

In another terminal window, start Optimism mainnet fork:

`npm run anvil:optimism:local`

Then run the deploy scripts in a third terminal window:
- `npm run deploy:ethereum-contracts:local`
- `npm run deploy:optimism-contracts:local`

### Mainnet

Use one of the following commands to deploy on the testnet of your choice.

#### Ethereum

To deploy the Ethereum mainnet contracts, run the following command:

`npm run deploy:contracts:ethereum`

#### Optimism

To deploy the Optimism mainnet contracts, run the following command:

`npm run deploy:contracts:optimism`

### Contract List

To generate the local contract list, run the following command: `npm run gen:local`

To generate the mainnet contract list, run the following command: `npm run gen:mainnet`
