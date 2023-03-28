// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Unit parameters
struct Unit {
    // Primary IPFS hash of the unit
    bytes32 unitHash;
    // Set of component dependencies (agents are also based on components)
    // We assume that the system is expected to support no more than 2^32-1 components
    uint32[] dependencies;
}


/// @title JobRegistry - Smart contract for mocking the registry for testing
/// @author Aleksandr Kuperman - <aleksandr.kuperman@valory.xyz>
contract MockRegistry {
    // Total supply
    uint256 public totalSupply;

    constructor(uint256 _totalSupply)
    {
        totalSupply = _totalSupply;
    }

    /// @dev Checks for the unit existence.
    /// @notice Unit counter starts from 1.
    /// @param unitId Unit Id.
    /// @return true if the unit exists, false otherwise.
    function exists(uint256 unitId) external view virtual returns (bool) {
        return unitId > 0 && unitId <= totalSupply;
    }

    /// @dev Gets the unit instance.
    /// @param unitId Unit Id.
    /// @return unit Corresponding Unit struct.
    function getUnit(uint256 unitId) external pure returns (Unit memory unit) {
        unit.unitHash = keccak256(abi.encodePacked(unitId));
    }
}
