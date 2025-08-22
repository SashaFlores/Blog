// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IERC165 } from '@openzeppelin/contracts/utils/introspection/IERC165.sol';

interface IBlog is IERC165 {

    error InvalidNewFee();
    error EmptyBalance();
    error WithdrawalFailedNoData();
    error LessThanPremiumFee(uint256 requiredFee);
    error NonTransferrable();
    error ContractNameChanged();
    error UpdateVersionToUpgrade();
    error EmptyURI();

    event FundsReceived(address indexed sender, uint256 amount);
    event FundsWithdrawn(address indexed recipient, uint256 amount);
    event PremiumReceived(address indexed sender, string tokenURI);

    function __Blog_init(address initialOwner, uint256 premiumFee, string calldata _uri) external;
    function balance() external view returns (uint256);
    function getPremiumFee() external view returns (uint256);
    function version() external pure returns (string memory);
    function contractName() external pure returns (string memory);
    function mint() external payable;
    function mintPremium(string calldata tokenURI) external payable;
    function pause() external;
    function unpause() external;
    function withdraw(address payable des) external;
    function updatePremiumFee(uint256 newFee) external;
    function modifyURI(string memory newuri) external;

}
