// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
}
