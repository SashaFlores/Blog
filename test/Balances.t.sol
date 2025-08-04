// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/Script.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { SetupTest } from "./Setup.t.sol";
import { IBlog } from "../src/IBlog.sol";
import { Blog } from "../src/Blog.sol";



contract BalancesTest is Test, SetupTest {

    error NonTransferrable();

    event FundsReceived(address indexed sender, uint256 amount);

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    event PremiumReceived(address indexed sender, string tokenURI);

    function test_mintStandard_withDonation() public {

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(nonPremiumUser, address(0x00), nonPremiumUser, 1, 1);

        vm.expectEmit(true, false, false, true);
        emit FundsReceived(nonPremiumUser, 0.01 ether);

        vm.prank(nonPremiumUser);
        vm.deal(nonPremiumUser, 0.01 ether);

        blog.mint{value: 0.01 ether}();

        assertEq(blog.balance(), 0.01 ether);
        assertEq(blog.balanceOf(nonPremiumUser, 1), 1);
    }

    function test_mintStandard_free() public {
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(nonPremiumUser, address(0x00), nonPremiumUser, 1, 1);

        vm.prank(nonPremiumUser);
        blog.mint();

        assertEq(blog.balanceOf(nonPremiumUser, 1), 1);
        assertEq(blog.balance(), 0 ether);
    }

    function testRevert_mintPremium_withoutFee() public {
        vm.expectRevert(abi.encodeWithSelector(IBlog.LessThanPremiumFee.selector, initialPremiumFee));

        vm.prank(nonPremiumUser);
        vm.deal(nonPremiumUser, 0.01 ether);

        blog.mintPremium("https://example.com/metadata/premium");

        assertEq(blog.balance(), 0 ether);
        assertEq(blog.balanceOf(nonPremiumUser, 2), 0);
    }

    function test_emitsRightURIEvent_premiumToken() public {

        
        vm.expectEmit(true, true, false, true);
        emit TransferSingle(premiumUser, address(0x00), premiumUser, uint256(blog.PREMIUM()), 1);

        vm.expectEmit(true, false, false, true);
        emit PremiumReceived(premiumUser, "https://www.sashaflores.xyz/articles/optimization-of-gas-and-bytecode-limitation");

        vm.prank(premiumUser);
        vm.deal(premiumUser, 1 ether);

        blog.mintPremium{value: 1 ether}("https://www.sashaflores.xyz/articles/optimization-of-gas-and-bytecode-limitation");

        assertEq(blog.balanceOf(premiumUser, uint256(blog.PREMIUM())), 1);
        assertEq(blog.balance(), 1 ether);
    }

    function testRevert_mintPremium_lessThanRequiredFee() public {

        vm.expectRevert(abi.encodeWithSelector(IBlog.LessThanPremiumFee.selector, initialPremiumFee));

        vm.prank(premiumUser);
        vm.deal(premiumUser, 0.01 ether);
        blog.mintPremium("https://example.com/metadata/premium");

        assertEq(blog.balanceOf(premiumUser, uint256(blog.PREMIUM())), 0);
        assertEq(blog.balance(), 0 ether);
    }

    
    /// forge-config: default.allow_internal_expect_revert = true
    function testRevert_nonTransferrable_premiumToken() public {

        vm.deal(premiumUser, 1 ether);
        vm.startPrank(premiumUser);
        
        blog.mintPremium{value: 0.05 ether}("https://example.com/metadata/premium");
        

        assertEq(blog.balanceOf(premiumUser, uint256(blog.PREMIUM())), 1);
        assertEq(blog.balance(), 0.05 ether);


        // blog.setApprovalForAll(address(this), true);
        // assertTrue(blog.isApprovedForAll(premiumUser, address(this)));
        
        // vm.expectRevert();
        // vm.prank(address(this));
        vm.expectPartialRevert(IBlog.NonTransferrable.selector);
        blog.safeTransferFrom(premiumUser, nonOwner, uint256(blog.PREMIUM()), 1, "");

        vm.stopPrank();
       
    }

    // function test_transferrable_StandardToken() public {

    //     vm.prank(nonPremiumUser);

    //     blog.mint();

    //     assertEq(blog.balanceOf(nonPremiumUser, 1), 1);

    //     // Transfer the standard token
    //     blog.safeTransferFrom(nonPremiumUser, nonOwner, 1, 1, "");

    //     assertEq(blog.balanceOf(nonPremiumUser, 1), 0);
    //     assertEq(blog.balanceOf(nonOwner, 1), 1);
    // }


}