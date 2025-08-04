// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IBlog {

    error InvalidNewFee();
    error EmptyBalance();
    error WithdrawalFailedNoData();
    error LessThanPremiumFee(uint256 requiredFee);
    error InvalidTokenId();
    error NonTransferrable();
    error ContractNameChanged();
    error EmptyURI();

    event FundsReceived(address indexed sender, uint256 amount);
    event FundsWithdrawn(address indexed recipient, uint256 amount);
    event PremiumReceived(address indexed sender, string tokenURI);

    
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