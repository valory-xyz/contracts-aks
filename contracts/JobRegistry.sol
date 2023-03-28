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
    uint256 numProposedPairs;

    // Cyclical map of all the job pairs
    mapping (uint256 => uint256) public mapProposedPairs;
    // Map of job address | componentId pair => proposer address
    mapping (uint256 => address) public mapPairProposers;
    // Map of accepted job address => component Id
    mapping (address => uint32) public mapAcceptedJobIds;

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
        uint256 currentPair;
        // Choose between an empty map and a map with already proposed pairs
        if (numPairs > 0) {
            currentPair = mapProposedPairs[SENTINEL];
        } else {
            currentPair = SENTINEL;
        }
        // Fill in the cyclic map of proposed pairs
        for (uint256 i = 0; i < jobs.length; ++i) {
            // job address occupies first 160 bits
            uint256 jobAddressComponentId = uint256(uint160(jobs[i]));
            // componentId occupies next 32 bits assuming it is not greater than 2^32 - 1 in value
            jobAddressComponentId |= componentIds[i] << 160;

            // Check if the job / component Id pair was already proposed
            if (mapProposedPairs[jobAddressComponentId] != 0) {
                revert AlreadyProposed(jobs[i], componentIds[i]);
            }

            // Link a current pair with the next one
            mapProposedPairs[currentPair] = jobAddressComponentId;
            // Record the pair proposer address
            mapPairProposers[jobAddressComponentId] = msg.sender;
            currentPair = jobAddressComponentId;
        }
        // Last pair always points to the sentinel value
        mapProposedPairs[currentPair] = SENTINEL;
        // Increase the number of proposed pairs
        numPairs += jobs.length;
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
            if (mapPairProposers[jobAddressComponentId] == address(0)) {
                revert NotProposed(jobs[i], componentIds[i]);
            }

            // Accept the pair
            mapAcceptedJobIds[jobs[i]] = uint32(componentIds[i]);
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

        for (uint256 i = 0; i < jobs.length; ++i) {
            // No need to check for the componentIds overflow since the msg.sender can remove only their proposed pairs

            // job address occupies first 160 bits
            uint256 jobAddressComponentId = uint256(uint160(jobs[i]));
            // componentId occupies next 32 bits assuming it is not greater than 2^32 - 1 in value
            jobAddressComponentId |= componentIds[i] << 160;

            // Check for the pair ownership
            if (msg.sender != owner || mapPairProposers[jobAddressComponentId] != msg.sender) {
                revert OwnerOnly(msg.sender, mapPairProposers[jobAddressComponentId]);
            }

            // Remove pairs both from mapPairProposers and mapAcceptedJobIds
            mapPairProposers[jobAddressComponentId] = address(0);
            mapAcceptedJobIds[jobs[i]] = 0;
        }
    }

    /// @dev Gets a set of proposed pairs.
    /// @return jobs Set of proposed job contract addresses.
    /// @return componentIds Set of corresponding component Ids.
    function getProposedPairs() external view returns (address[] memory jobs, uint256[] memory componentIds) {
        // Get the total number of proposed pairs
        uint256 numPairs = numProposedPairs;
        if (numPairs == 0) {
            return (jobs, componentIds);
        }

        uint256[] memory pairs = new uint256[](numPairs);
        uint256 numActualPairs;

        // Traverse through all the proposed pairs
        uint256 currentPair = mapProposedPairs[SENTINEL];
        while (currentPair != SENTINEL) {
            // Discard removed pairs
            if (mapPairProposers[currentPair] != address(0)) {
                pairs[numActualPairs] = currentPair;
                currentPair = mapProposedPairs[currentPair];
                numActualPairs++;
            }
        }

        // Unpakc and return the actual number of job contract addresses and component Ids
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

    /// @dev Gets a set of accepted pairs.
    /// @return jobs Set of accepted job contract addresses.
    /// @return componentIds Set of corresponding component Ids.
    function getAcceptedPairs() external view returns (address[] memory jobs, uint256[] memory componentIds) {
        // Get the total number of proposed pairs
        uint256 numPairs = numProposedPairs;
        if (numPairs == 0) {
            return (jobs, componentIds);
        }

        uint256[] memory pairs = new uint256[](numPairs);
        uint256 numActualPairs;

        // Traverse through all the proposed pairs
        uint256 currentPair = mapProposedPairs[SENTINEL];
        while (currentPair != SENTINEL) {
            // Collect accepted pairs or discard removed pairs
            if (mapAcceptedJobIds[address(uint160(currentPair))] != 0) {
                pairs[numActualPairs] = currentPair;
                currentPair = mapProposedPairs[currentPair];
                numActualPairs++;
            }
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
    function isAccepted(address job) external view returns (bool accepted) {
        // Get the component Id
        uint256 componentId = mapAcceptedJobIds[job];
        accepted = componentId > 0;
    }
}
