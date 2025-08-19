// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IBlog {

    function version() external pure returns (string memory);
    function contractName() external pure returns (string memory);

}

/// @custom:oz-upgrades-from Blog
/// @custom:oz-upgrades-to MockBlogFailureUpgrade
contract MockBlogFailureUpgrade is IBlog {

    /// @notice Keep the same name so the first check passes
    function contractName() external pure returns (string memory) {
        return 'Blog';
    }

    /// @notice Keep the same version so the second check fails & trigger the failure
    function version() external pure returns (string memory) {
        return '1.0.0';
    }

}
