# Internal audit of contracts-aks
The review has been performed based on the contract code in the following repository:<br>
`https://github.com/valory-xyz/contracts-aks` <br>
commit: `f3564628bdd3f7bacee37e2b21cb39b63cb0d6c0` <br> 

## Objectives
The audit focused on contracts in this repo.

### Flatten version
Flatten version of contracts. [contracts](https://github.com/valory-xyz/contracts-aks/blob/main/audits/internal/analysis/contracts)

### Security issues.
#### Problems found instrumentally
All automatic warnings are listed in the following file, concerns of which we address in more detail below: <br>
[slither-full](https://github.com/valory-xyz/contracts-aks/blob/main/audits/internal/analysis/slither_full.txt) <br>

#### No event in key functions: propose, accept, remove

#### no need to check and just delete
```
            if (mapAcceptedJobIds[jobs[i]] != 0) {
                mapAcceptedJobIds[jobs[i]] = 0;
            }
```
#### refactoring in future versions. optional 
Pay attention (maybe for the next version):
```
            bool pairAlreadyExists = (mapProposals[jobAddressComponentId] != 0);
            // Check if the job / component Id pair was already proposed
            if ((pairAlreadyExists && mapPairAccounts[jobAddressComponentId] != address(0)) ||
                currentPair == jobAddressComponentId) {
                revert AlreadyProposed(jobs[i], componentIds[i]);
            }

            // If the pair was already proposed before (then removed and proposed again), do not add it in the map
            if (!pairAlreadyExists) {
                // Link a current pair with the next one
                mapProposals[currentPair] = jobAddressComponentId;
                currentPair = jobAddressComponentId;
                // Increase the number of proposed pairs
                numPairs++;
            }
conditions don't look symmetrical
(pairAlreadyExists && mapPairAccounts[jobAddressComponentId] != address(0)) 
currentPair == jobAddressComponentId

For the very first iteration when the first one element is added:
currentPair == SENTINEL
mapProposals[currentPair] = jobAddressComponentId
mapProposals[SENTINEL] = jobAddressComponentId
mapProposals[jobAddressComponentId] == 0
so
pairAlreadyExists = mapProposals[jobAddressComponentId] != 0 => false
That is, it will most likely work correctly.
pairAlreadyExists - a little confusing. Given the urgency of development, let will be as is.
```
