# Autonomous Keeper Service

## Introduction
This repository contains the Autonomous Keeper Service contracts.

Here is the list of the contracts:
- [JobRegistry](https://github.com/valory-xyz/contracts-aks/blob/main/contracts/JobRegistry.sol)

## Development

### Prerequisites
- This repository follows the standard [`Hardhat`](https://hardhat.org/tutorial/) development process.
- The code is written on Solidity `0.8.19`.
- The standard versions of Node.js along with Yarn are required to proceed further (confirmed to work with Yarn `1.22.19` and npm `8.19.3` and node `v18.13.0`);

### Install the dependencies
The dependency list is managed by the `package.json` file, and the setup parameters are stored in the `hardhat.config.js` file.
Simply run the following command to install the project:
```
yarn install
```

### Core components
The contracts, deploy scripts and tests are located in the following folders respectively:
```
contracts
scripts
test
```

### Compile the code and run
Compile the code:
```
npx hardhat compile
```
Run tests with Hardhat:
```
npx hardhat test
```

### Audits
The audit is provided as development matures. The latest audit reports can be found here: [audits](https://github.com/valory-xyz/contracts-aks/blob/main/audits).

### Linters
- [`ESLint`](https://eslint.org) is used for JS code.
- [`solhint`](https://github.com/protofire/solhint) is used for Solidity linting.

### Github workflows
The PR process is managed by github workflows, where the code undergoes several steps in order to be verified. Those include:
- code installation;
- running linters;
- running tests;
- checking for hardcoded secrets.

## Deployment
The deployment of contracts to the test- and main-net is split into step-by-step series of scripts for more control and checkpoint convenience.
The description of deployment procedure can be found here: [deployment](https://github.com/valory-xyz/contracts-aks/blob/main/scripts/deployment).

The finalized contract ABIs for deployment and their number of optimization passes are located here: [ABIs](https://github.com/valory-xyz/contracts-aks/blob/main/abis).

## Acknowledgements
These contracts were inspired and based on the following sources:
- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts);
- [Safe Ecosystem](https://github.com/safe-global/safe-contracts).