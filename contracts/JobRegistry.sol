// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IRegistry.sol";

// Struct of job address and a component Id
struct jobPair {
    // Job address
    address job;
    // Component Id
    uint32 id;
}

/// @dev Provided zero address.
error ZeroAddress();

/// @title JobRegistry - Smart contract for dynamically approving component Ids and job addresses
/// @author Aleksandr Kuperman - <aleksandr.kuperman@valory.xyz>
contract JobRegistry {
    event OwnerUpdated(address indexed owner);

    // Component registry address
    address public immutable componentRegistry;
    // Owner address
    address public owner;

    // Cyclical map of job pairs
    mapping (jobPair => jobPair) public proposedPairs;
    // Map of jobPair => proposer address
    mapping (jobPair => address) public pairProposers;
    // Map of job address => component Id
    mapping (address => uint32) public approvedPairs;

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
}
