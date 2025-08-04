// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract MockBlogV2Failure {

    // Keep the same name so the first check passes
    function contractName() external pure returns (string memory) {
        return "Blog";
    }

    // Keep the same version so the second check fails (`!= 1.0.0`)
    function version() external pure returns (string memory) {
        return "1.0.0"; // This should be different to trigger the failure
    }
}