// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IBlog {
    function mint() external payable;
    function mintPremium(string calldata tokenURI) external payable;
    function getPremiumFee() external view returns (uint256);
    function balance() external view returns (uint256);
    function pause() external;
    function unpause() external;
    function withdraw(address payable des) external;
    function updatePremiumFee(uint256 newFee) external;
    function modifyURI(string memory newuri) external;
    function version() external pure returns (string memory);
    function contractName() external pure returns (string memory);
}