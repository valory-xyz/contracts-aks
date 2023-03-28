// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IErrors.sol";
import "./interfaces/IRegistry.sol";

/// @title JobRegistry - Smart contract for dynamically approving component Ids and job contract addresses
/// @author Aleksandr Kuperman - <aleksandr.kuperman@valory.xyz>
contract JobRegistry is IErrors {
    event OwnerUpdated(address indexed owner);

    // Sentinel value
    uint256 public constant SENTINEL = 1;
    // Component registry address
    address public immutable componentRegistry;
    // Owner address
    address public owner;
    // Number of proposed job contract address | component Id pairs
    uint256 public numProposedPairs;

    // Cyclical map of all the job pairs
    mapping (uint256 => uint256) public mapProposals;
    // Map of job address | componentId pair => proposer account address
    mapping (uint256 => address) public mapPairAccounts;
    // Map of accepted job address => component Id
    mapping (address => uint256) public mapAcceptedJobIds;

    /// @dev JobRegistry constructor.
    /// @param _componentRegistry Component registry address.
    constructor(address _componentRegistry)
    {
        owner = msg.sender;

        // Check for at least one zero contract address
        if (_componentRegistry == address(0)) {
            revert ZeroAddress();
        }

        componentRegistry = _componentRegistry;
    }

    /// @dev Changes the owner address.
    /// @param newOwner Address of a new owner.
    function changeOwner(address newOwner) external {
        // Check for the contract ownership
        if (msg.sender != owner) {
            revert OwnerOnly(msg.sender, owner);
        }

        // Check for the zero address
        if (newOwner == address(0)) {
            revert ZeroAddress();
        }

        owner = newOwner;
        emit OwnerUpdated(newOwner);
    }

    /// @dev Propose [job contract address | component Id] pairs.
    /// @param jobs Set of job contract addresses.
    /// @param componentIds Set of component Ids.
    function propose(address[] memory jobs, uint256[] memory componentIds) external {
        // Check input array lengths
        if (jobs.length != componentIds.length) {
            revert WrongArrayLength(jobs.length, componentIds.length);
        }
        if (jobs.length == 0) {
            revert ZeroValue();
        }

        // Verification loop
        for (uint256 i = 0; i < jobs.length; ++i) {
            // Check for zero inputs
            if (jobs[i] == address(0)) {
                revert ZeroAddress();
            }
            if (componentIds[i] == 0) {
                revert ZeroValue();
            }

            // Check for the component Id overflow
            if (componentIds[i] > type(uint32).max) {
                revert Overflow(componentIds[i], type(uint32).max);
            }

            // Check for the component existence
            if (!IRegistry(componentRegistry).exists(componentIds[i])) {
                revert ComponentDoesNotExist(componentIds[i]);
            }
        }

        uint256 numPairs = numProposedPairs;
        uint256 initNumPairs = numPairs;
        uint256 currentPair = SENTINEL;
        // Record the first value if the map is not empty such that it is adjusted at the end
        uint256 firstPair;
        if (numPairs > 0) {
            firstPair = mapProposals[SENTINEL];
        }
        // Fill in the cyclic map of proposed pairs
        for (uint256 i = 0; i < jobs.length; ++i) {
            // job address occupies first 160 bits
            uint256 jobAddressComponentId = uint256(uint160(jobs[i]));
            // componentId occupies next 32 bits assuming it is not greater than 2^32 - 1 in value
            jobAddressComponentId |= componentIds[i] << 160;

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
            // Record the pair proposer address
            mapPairAccounts[jobAddressComponentId] = msg.sender;
        }
        if (initNumPairs == 0) {
            // Last pair points to the sentinel value if adding to the map the first time
            mapProposals[currentPair] = SENTINEL;
        } else if (currentPair != SENTINEL) {
            // If currentPair is still equal to SENTINEL, then no new jobs were added
            // Last pair points to the first value before adding new proposals if the map was not empty
            mapProposals[currentPair] = firstPair;
        }
        numProposedPairs = numPairs;
    }

    /// @dev Accept [job contract address | component Id] pairs.
    /// @notice This function must be called by the contract owner.
    /// @param jobs Set of job contract addresses.
    /// @param componentIds Set of component Ids.
    function accept(address[] memory jobs, uint256[] memory componentIds) external {
        // Check for the ownership
        if (msg.sender != owner) {
            revert OwnerOnly(msg.sender, owner);
        }

        // Check input array lengths
        if (jobs.length != componentIds.length) {
            revert WrongArrayLength(jobs.length, componentIds.length);
        }
        if (jobs.length == 0) {
            revert ZeroValue();
        }

        for (uint256 i = 0; i < jobs.length; ++i) {
            // Check for the component Id overflow
            if (componentIds[i] > type(uint32).max) {
                revert Overflow(componentIds[i], type(uint32).max);
            }

            // job address occupies first 160 bits
            uint256 jobAddressComponentId = uint256(uint160(jobs[i]));
            // componentId occupies next 32 bits assuming it is not greater than 2^32 - 1 in value
            jobAddressComponentId |= componentIds[i] << 160;

            // Check for the existence of the pair
            if (mapPairAccounts[jobAddressComponentId] == address(0)) {
                revert NotProposed(jobs[i], componentIds[i]);
            }

            // Accept the pair
            mapAcceptedJobIds[jobs[i]] = componentIds[i];
        }
    }

    /// @dev Remove [job contract address | component Id] pairs.
    /// @notice This function must be called by the address that proposed pairs initially or the contract owner.
    /// @param jobs Set of job contract addresses.
    /// @param componentIds Set of component Ids.
    function remove(address[] memory jobs, uint256[] memory componentIds) external {
        // Check input array lengths
        if (jobs.length != componentIds.length) {
            revert WrongArrayLength(jobs.length, componentIds.length);
        }
        if (jobs.length == 0) {
            revert ZeroValue();
        }

        for (uint256 i = 0; i < jobs.length; ++i) {
            // No need to check for the componentIds overflow since the msg.sender can remove only their proposed pairs

            // job address occupies first 160 bits
            uint256 jobAddressComponentId = uint256(uint160(jobs[i]));
            // componentId occupies next 32 bits assuming it is not greater than 2^32 - 1 in value
            jobAddressComponentId |= componentIds[i] << 160;

            // Check for the pair ownership
            if (msg.sender != owner && msg.sender != mapPairAccounts[jobAddressComponentId]) {
                revert OwnerOnly(msg.sender, mapPairAccounts[jobAddressComponentId]);
            }

            // Remove pairs both from mapPairAccounts and mapAcceptedJobIds
            mapPairAccounts[jobAddressComponentId] = address(0);
            if (mapAcceptedJobIds[jobs[i]] != 0) {
                mapAcceptedJobIds[jobs[i]] = 0;
            }
        }
    }

    /// @dev Gets a set of accepted or proposed pairs.
    /// @param accepted Flag to return accepted pairs only.
    /// @return jobs Set of job contract addresses.
    /// @return componentIds Set of corresponding component Ids.
    function getPairs(bool accepted) external view returns (address[] memory jobs, uint256[] memory componentIds) {
        // Get the total number of proposed pairs
        uint256 numPairs = numProposedPairs;
        if (numPairs == 0) {
            return (jobs, componentIds);
        }

        uint256[] memory pairs = new uint256[](numPairs);
        uint256 numActualPairs;

        // Traverse through all the proposed pairs
        uint256 currentPair = SENTINEL;
        for (uint256 i = 0; i < numPairs; ++i) {
            currentPair = mapProposals[currentPair];
            // Discard removed pairs
            // If accepted, check for the component Id to match with the map value,
            if ((accepted && mapAcceptedJobIds[address(uint160(currentPair))] == currentPair >> 160) ||
                // otherwise discard removed pairs
                (!accepted && mapPairAccounts[currentPair] != address(0))) {
                pairs[numActualPairs] = currentPair;
                numActualPairs++;
            }
        }
        if (numActualPairs == 0) {
            return (jobs, componentIds);
        }

        // Unpack and return the actual number of job contract addresses and component Ids
        jobs = new address[](numActualPairs);
        componentIds = new uint256[](numActualPairs);
        // Copy actual arrays
        for (uint256 i = 0; i < numActualPairs; ++i) {
            uint256 jobAddressComponentId = pairs[i];
            // job address occupies first 160 bits
            jobs[i] = address(uint160(jobAddressComponentId));
            // componentId occupies next 32 bits assuming it is not greater than 2^32 - 1 in value
            componentIds[i] = jobAddressComponentId >> 160;
        }
    }

    /// @dev Gets a component Id and a component hash of an accepted job contract address.
    /// @param job Job contract address.
    /// @return componentId Component Id.
    /// @return componentHash Component hash.
    function getComponentIdHash(address job) external view returns (uint256 componentId, bytes32 componentHash) {
        // Get the component Id
        componentId = mapAcceptedJobIds[job];
        if (componentId == 0) {
            return (componentId, componentHash);
        }

        // Get the component hash
        IRegistry.Unit memory unit = IRegistry(componentRegistry).getUnit(componentId);
        componentHash = unit.unitHash;
    }

    /// @dev Checks if the job contract address is accepted.
    /// @param job Job contract address.
    /// @return accepted True if the job contract address is accepted.
    function isAcceptedJob(address job) external view returns (bool accepted) {
        accepted = (mapAcceptedJobIds[job] > 0);
    }

    /// @dev Checks if the job contract address corresponding to a specific componentId is accepted.
    /// @param job Job contract address.
    /// @param componentId Component Id.
    /// @return accepted True if the job contract address is accepted.
    function isAcceptedJobComponentId(address job, uint256 componentId) external view returns (bool accepted) {
        accepted = (mapAcceptedJobIds[job] == componentId);
    }
}
