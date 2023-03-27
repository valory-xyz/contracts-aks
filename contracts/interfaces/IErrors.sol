// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Errors.
interface IErrors {
    /// @dev Only `owner` has a privilege, but the `sender` was provided.
    /// @param sender Sender address.
    /// @param owner Required sender address as an owner.
    error OwnerOnly(address sender, address owner);

    /// @dev Provided zero address.
    error ZeroAddress();

    /// @dev Wrong length of two arrays.
    /// @param numValues1 Number of values in a first array.
    /// @param numValues2 Number of values in a second array.
    error WrongArrayLength(uint256 numValues1, uint256 numValues2);

    /// @dev Component Id does not exist in registry records.
    /// @param componentId ComponentId Id.
    error ComponentDoesNotExist(uint256 componentId);

    /// @dev Zero value when it has to be different from zero.
    error ZeroValue();

    /// @dev Job contract address | component Id is already proposed.
    /// @param job Job contract address.
    /// @param componentId Component Id.
    error AlreadyProposed(address job, uint256 componentId);
}
