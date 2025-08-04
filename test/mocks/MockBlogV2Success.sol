// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;


contract MockBlogV2Success {

    // Keep the same name so the first check passes
    function contractName() external pure returns (string memory) {
        return "Blog";
    }

    // Bump the version so the second check passes (`!= 1.0.0`)
    function version() external pure returns (string memory) {
        return "1.1.0";
    }
}