// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/Script.sol";
import { Blog } from "../src/Blog.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { SetupTest } from "./01_Setup.t.sol";


contract OwnerTest is Test, SetupTest {
    
    // Blog public blog;


    // function setUp() public {
    //     address implementation = address(new Blog());
    //     address proxy = UnsafeUpgrades.deployUUPSProxy(
    //         implementation,
    //         abi.encodeCall(Blog.__Blog_init, (address(this), 0.01 ether, "https://example.com/metadata/"))
    //     );

    //     blog = Blog(payable(proxy));

    //     nonOwner = address(0x123);
    // }

    function test_initialOwner() public {
        assertEq(blog.owner(), address(this));
    }

    function test_premiumFee() public {
        assertEq(blog.getPremiumFee(), initialPremiumFee);
    }

    function testRevert_transferOwnership() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0x00)));
        blog.transferOwnership(address(0x00));
    }

    function testRevert_nonOwnerCannotTransferOwnership() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        blog.transferOwnership(nonOwner);
    }

    function test_ownerRenouncesOwnership() public {
        vm.prank(address(this));
        blog.renounceOwnership();
        assertEq(blog.owner(), address(0));
    }

    function testRevert_nonOwnerCannotRenounceOwnership() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        blog.renounceOwnership();
    }

    function test_ownerChangeFee() public {
        uint256 newFee = 0.02 ether;
        vm.prank(address(this));
        blog.updatePremiumFee(newFee);
        assertEq(blog.getPremiumFee(), newFee);
    }

    function testRevert_nonOwnerCannotChangeFee() public {
        uint256 newFee = 10 ether;
        vm.prank(premiumUser);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, premiumUser));
        blog.updatePremiumFee(newFee);
    }

    function testRevert_onlyOwnerChangeURI() public {
        string memory newURI = "https://new.example.com/metadata/";
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        blog.modifyURI(newURI);
    }
}