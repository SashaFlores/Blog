// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/Script.sol";
import { Blog } from "../src/Blog.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { SetupTest } from "./Setup.t.sol";


contract OwnerTest is Test, SetupTest {

    event FundsWithdrawn(address indexed to, uint256 amount);

    

    function test_initialOwner() public {
        assertEq(blog.owner(), address(this));
    }

    function test_premiumFee() public {
        assertEq(blog.getPremiumFee(), initialPremiumFee);
    }

    function testRevert_transferOwnership_toZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0x00)));
        blog.transferOwnership(address(0x00));
    }

    function testRevert_notOwner_transferOwnership() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        blog.transferOwnership(nonOwner);
    }

    function test_ownerRenouncesOwnership() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(this), address(0));

        vm.prank(address(this));
        blog.renounceOwnership();

        assertEq(blog.owner(), address(0));
    }

    function testRevert_notOwner_renounceOwnership() public {
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

    function testRevert_notOwner_changeFee() public {
        uint256 newFee = 10 ether;
        vm.prank(premiumUser);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, premiumUser));
        
        blog.updatePremiumFee(newFee);
    }

    function testRevert_onlyOwnerChangeURI() public {
        assertEq(blog.uri(0), URI);

        string memory newURI = "https://new.example.com/metadata/";
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        
        blog.modifyURI(newURI);
    }

    function test_OwnerWithdrawsFunds() public {
        vm.deal(address(blog), 1 ether);

        vm.prank(address(this));

        console.log("Blog balance before withdrawal:", blog.balance());

        address payable recipient = nonOwner;

        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(recipient, 1 ether);

        
        blog.withdraw(recipient);

        assertEq(recipient.balance, 1 ether);
        console.log("Blog balance after withdrawal:", blog.balance());
        console.log("Non-owner balance after withdrawal:", recipient.balance);
    }
}