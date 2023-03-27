// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Required interface for the registry.
interface IRegistry {
    // Unit parameters
    struct Unit {
        // Primary IPFS hash of the unit
        bytes32 unitHash;
        // Set of component dependencies (agents are also based on components)
        // We assume that the system is expected to support no more than 2^32-1 components
        uint32[] dependencies;
    }

    /// @dev Checks if the unit Id exists.
    /// @param unitId Unit Id.
    /// @return true if the unit exists, false otherwise.
    function exists(uint256 unitId) external view returns (bool);

    /// @dev Gets the unit instance.
    /// @param unitId Unit Id.
    /// @return unit Corresponding Unit struct.
    function getUnit(uint256 unitId) external view returns (Unit memory unit);
}
