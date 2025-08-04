// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/Script.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { SetupTest } from "./Setup.t.sol";
import { IBlog } from "../../src/IBlog.sol";
import { Blog } from "../../src/Blog.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";




contract BalancesTest is Test, SetupTest {

    error NonTransferrable();

    event FundsReceived(address indexed sender, uint256 amount);

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    event PremiumReceived(address indexed sender, string tokenURI);

    function test_mintStandard_withDonation() public {

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(nonPremiumUser, address(0x00), nonPremiumUser, uint256(blog.STANDARD()), 1);

        vm.expectEmit(true, false, false, true);
        emit FundsReceived(nonPremiumUser, 0.01 ether);

        vm.prank(nonPremiumUser);
        vm.deal(nonPremiumUser, 0.01 ether);

        blog.mint{value: 0.01 ether}();

        assertEq(blog.balance(), 0.01 ether);
        assertEq(blog.balanceOf(nonPremiumUser, uint256(blog.STANDARD())), 1);
        assertEq(blog.totalSupply(uint256(blog.STANDARD())), 1);
    }

    function test_mintStandard_free() public {
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(nonPremiumUser, address(0x00), nonPremiumUser, uint256(blog.STANDARD()), 1);

        vm.prank(nonPremiumUser);
        blog.mint();

        assertEq(blog.balanceOf(nonPremiumUser, uint256(blog.STANDARD())), 1);
        assertEq(blog.balance(), 0 ether);
        assertEq(blog.totalSupply(uint256(blog.STANDARD())), 1);
    }

    function testRevert_mintPremium_withoutFee() public {
        vm.expectRevert(abi.encodeWithSelector(IBlog.LessThanPremiumFee.selector, initialPremiumFee));

        vm.prank(nonPremiumUser);
        vm.deal(nonPremiumUser, 0.01 ether);

        blog.mintPremium("https://example.com/metadata/premium");

        assertEq(blog.balance(), 0 ether);
        assertEq(blog.balanceOf(nonPremiumUser, uint256(blog.PREMIUM())), 0);
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

    function testRevert_whenPaused_mintDisabled() public {
        
        blog.pause();
        assertTrue(blog.paused());

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(nonPremiumUser);
        blog.mint();

        assertEq(blog.balanceOf(nonPremiumUser, uint256(blog.STANDARD())), 0);

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(premiumUser);
        vm.deal(premiumUser, 1 ether);

        blog.mintPremium{value: initialPremiumFee}("https://example.com/metadata/premium");
        assertEq(blog.balanceOf(premiumUser, uint256(blog.PREMIUM())), 0);

        blog.unpause();
        assertFalse(blog.paused());

        vm.prank(nonPremiumUser);
        blog.mint();
        assertEq(blog.balanceOf(nonPremiumUser, uint256(blog.STANDARD())), 1);
    }

    function test_totalSupply_contractBalance() public {

        vm.deal(premiumUser, 3 ether);
        vm.startPrank(premiumUser);

        blog.mintPremium{value: initialPremiumFee}("https://example.com/metadata/premium");
        blog.mintPremium{value: initialPremiumFee}("https://example.com/metadata/premium");
        blog.mintPremium{value: initialPremiumFee}("https://example.com/metadata/premium");

        assertEq(blog.totalSupply(uint256(blog.PREMIUM())), 3);
        assertEq(blog.balanceOf(premiumUser, uint256(blog.PREMIUM())), 3);
        uint256 totalPremiumReceived = initialPremiumFee * 3;
        assertEq(blog.balance(), totalPremiumReceived);
        vm.stopPrank();

        vm.startPrank(nonPremiumUser);
        vm.deal(nonPremiumUser, 1 ether);
        uint256 donation = 1 ether;
        blog.mint{value: donation}();
        blog.mint();
        blog.mint();
        blog.mint();
        assertEq(blog.totalSupply(uint256(blog.STANDARD())), 4);
        assertEq(blog.balanceOf(nonPremiumUser, uint256(blog.STANDARD())), 4);
        uint256 totalReceived = totalPremiumReceived + donation;
        assertEq(blog.balance(), totalReceived);
        vm.stopPrank();
    }


    function test_transferrable_StandardToken() public {

        vm.startPrank(nonPremiumUser);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(nonPremiumUser, address(0x00), nonPremiumUser, uint256(blog.STANDARD()), 1);
        blog.mint();

        assertEq(blog.balanceOf(nonPremiumUser,  uint256(blog.STANDARD())), 1);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(nonPremiumUser, nonPremiumUser, nonOwner,  uint256(blog.STANDARD()), 1);
        blog.safeTransferFrom(nonPremiumUser, nonOwner,  uint256(blog.STANDARD()), 1, "");

        assertEq(blog.balanceOf(nonPremiumUser,  uint256(blog.STANDARD())), 0);
        assertEq(blog.balanceOf(nonOwner,  uint256(blog.STANDARD())), 1);

        vm.stopPrank();
    }

    function testRevert_whenPaused_noTransfer_StandardToken() public {

        vm.prank(nonPremiumUser);
        blog.mint();
        assertEq(blog.balanceOf(nonPremiumUser,  uint256(blog.STANDARD())), 1);



        blog.pause();
        assertTrue(blog.paused());

        
        vm.startPrank(nonPremiumUser);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        blog.safeTransferFrom(nonPremiumUser, nonOwner,  uint256(blog.STANDARD()), 1, "");

        assertEq(blog.balanceOf(nonPremiumUser,  uint256(blog.STANDARD())), 1);
        assertEq(blog.balanceOf(nonOwner,  uint256(blog.STANDARD())), 0);
        vm.stopPrank();
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testRevert_nonTransferrable_premiumToken() public {

        vm.deal(premiumUser, 1 ether);
        vm.startPrank(premiumUser);
        
        blog.mintPremium{value: initialPremiumFee}("https://example.com/metadata/premium");
        

        assertEq(blog.balanceOf(premiumUser, uint256(blog.PREMIUM())), 1);
        assertEq(blog.balance(), 0.05 ether);

  
        vm.expectPartialRevert(IBlog.NonTransferrable.selector);
        blog.safeTransferFrom(premiumUser, nonOwner, uint256(blog.PREMIUM()), 1, "");

        vm.stopPrank();
       
    }

}