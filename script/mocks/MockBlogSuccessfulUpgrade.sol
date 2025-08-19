// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IBlog {

    function version() external pure returns (string memory);
    function contractName() external pure returns (string memory);

}

/// @custom:oz-upgrades-from Blog
/// @custom:oz-upgrades-to MockBlogSuccessfulUpgrade
contract MockBlogSuccessfulUpgrade is IBlog {

    /// @notice Keep the same name so the first check passes
    function contractName() external pure returns (string memory) {
        return 'Blog';
    }

    /// @notice Upgrade the version so the second check passes (`!= 1.0.0`)
    function version() external pure returns (string memory) {
        return '1.1.0';
    }

}
