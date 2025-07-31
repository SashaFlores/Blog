// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/Script.sol";
import { Blog } from "../src/Blog.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


contract SetupTest is Test {
    
    Blog public blog;

    address public nonOwner;
    address public premiumUser;
    address public nonPremiumUser;

    uint256 public initialPremiumFee = 0.01 ether;

    function setUp() public {
        address implementation = address(new Blog());
        address proxy = UnsafeUpgrades.deployUUPSProxy(
            implementation,
            abi.encodeCall(Blog.__Blog_init, (address(this), initialPremiumFee, "https://example.com/metadata/"))
        );

        blog = Blog(payable(proxy));

        nonOwner = address(0x123);
        premiumUser = address(0x456);
        nonPremiumUser = address(0x789);
    }

    // function test_initialOwner() public {
    //     assertEq(blog.owner(), address(this));
    // }

    // function test_premiumFee() public {
    //     assertEq(blog.getPremiumFee(), 0.01 ether);
    // }

    // function testRevert_transferOwnership() public {
    //     vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0x00)));
    //     blog.transferOwnership(address(0x00));
    // }

    // function testRevert_nonOwnerCannotTransfer() public {
    //     vm.prank(nonOwner);
    //     vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
    //     blog.transferOwnership(nonOwner);
    // }


}