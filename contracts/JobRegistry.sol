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

    // Cyclical map of job pairs
    mapping (uint256 => uint256) public mapProposedPairs;
    // Map of job address | componentId pair => proposer address
    mapping (uint256 => address) public mapPairProposers;
    // Map of job address => component Id
    mapping (address => uint32) public mapApprovedPairs;

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

    /// @dev Propose the job contract address | component Id pairs.
    /// @param jobs Set of job contract addresses.
    /// @param componentIds Set of component Ids.
    function propose(address[] memory jobs, uint256[] memory componentIds) external {
        // Check input array lengths
        if (jobs.length != componentIds.length) {
            revert WrongArrayLength(jobs.length, componentIds.length);
        }

        // Initial verification loop
        for (uint256 i = 0; i < jobs.length; ++i) {
            // Check for zero inputs
            if (jobs[i] == address(0)) {
                revert ZeroAddress();
            }
            if (componentIds[i] == 0) {
                revert ZeroValue();
            }

            // Check for the component existence
            if (!IRegistry(componentRegistry).exists(componentIds[i])) {
                revert ComponentDoesNotExist(componentIds[i]);
            }
        }

        uint256 numPairs = numProposedPairs;
        uint256 currentPair;
        // Choose between the
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
}
