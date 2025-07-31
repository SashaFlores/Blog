// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/Script.sol";
import { Blog } from "../src/Blog.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";



contract SetupTest is Test {
    
    Blog public blog;

    address payable public nonOwner;
    address public premiumUser;
    address public nonPremiumUser;

    uint256 public initialPremiumFee = 0.01 ether;
    string public URI = "https://example.com/metadata/";

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {

        nonOwner = payable(address(0x123));
        premiumUser = address(0x456);
        nonPremiumUser = address(0x789);

        // Deploy the Blog contract with initial parameters
        address implementation = address(new Blog());
        address proxy = UnsafeUpgrades.deployUUPSProxy(
            implementation,
            abi.encodeCall(Blog.__Blog_init, (address(this), initialPremiumFee, URI))
        );

        blog = Blog(payable(proxy));

    }
}