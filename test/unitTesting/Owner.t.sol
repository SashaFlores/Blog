// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/Script.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { SetupTest } from "./Setup.t.sol";
import { IBlog } from "../../src/IBlog.sol";
import {RevertingReceiver} from "../mocks/RevertingReceiver.sol";
import { SilentRejector } from "../mocks/SilentRejector.sol";


contract OwnerTest is Test, SetupTest {

    event FundsWithdrawn(address indexed recipient, uint256 amount);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    event Paused(address account);

    event Unpaused(address account);


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

    function test_ownerRenounces_ownership() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(this), address(0));

        blog.renounceOwnership();

        assertEq(blog.owner(), address(0));
    }

    function testRevert_notOwner_renounceOwnership() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        blog.renounceOwnership();
    }

    function test_ownerChangeFee() public {

        assertEq(blog.getPremiumFee(), initialPremiumFee);
        uint256 newFee = 0.02 ether;

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
        assertEq(blog.balance(), 1 ether);

        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(nonOwner, 1 ether);


        blog.withdraw(nonOwner);

        assertEq(nonOwner.balance, 1 ether);
        assertEq(blog.balance(), 0);
    }

    function testRevert_notOwner_withdraw() public {
        vm.deal(address(blog), 1 ether);

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        
        blog.withdraw(nonOwner);
        assertEq(nonOwner.balance, 0);
        assertEq(blog.balance(), 1 ether);
    }

    function test_whenPaused_ownerCanWithdraw() public {
        vm.deal(address(blog), 1 ether);
        assertEq(blog.balance(), 1 ether);

        blog.pause();
        
        blog.withdraw(nonOwner);
        assertEq(nonOwner.balance, 1 ether);
    }

    function test_whenPaused_ownerCanChangeFee() public {
        assertEq(blog.getPremiumFee(), initialPremiumFee);

        uint256 newFee = 5 ether;
        blog.pause();
        
        blog.updatePremiumFee(newFee);
        assertEq(blog.getPremiumFee(), newFee);
    }

    function testRevert_whenNewFeeIsZero_orEqualExisting() public {
        assertEq(blog.getPremiumFee(), initialPremiumFee);

        vm.expectRevert(IBlog.InvalidNewFee.selector);
        blog.updatePremiumFee(0);
        assertEq(blog.getPremiumFee(), initialPremiumFee);

        vm.expectRevert(IBlog.InvalidNewFee.selector);
        blog.updatePremiumFee(initialPremiumFee);
        assertEq(blog.getPremiumFee(), initialPremiumFee);
    }

    function testRevert_whenBalanceIsZero_withdraw() public {

        assertEq(blog.balance(), 0);

        vm.expectRevert(IBlog.EmptyBalance.selector);
        blog.withdraw(nonOwner);

        assertEq(nonOwner.balance, 0);
        assertEq(blog.balance(), 0);
    }

    function testRevert_whenUriIsEmpty_modifyURI() public {
        assertEq(blog.uri(0), URI);

        string memory emptyURI = "";
        
        vm.expectRevert(IBlog.EmptyURI.selector);
        blog.modifyURI(emptyURI);
        assertEq(blog.uri(0), URI);
    }   

    function test_onlyOwner_canPause() public {
        assertFalse(blog.paused());

        vm.expectEmit(false, false, false, true);
        emit Paused(address(this));

        blog.pause();
        assertTrue(blog.paused());
    }

    function testRevert_notOwner_paused() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        blog.pause();
    }

    function testRevert_pause_whenAlreadyPaused() public {
        assertFalse(blog.paused());

        blog.pause();
        assertTrue(blog.paused());

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        blog.pause();
    }

    function test_onlyOwner_canUnpause() public {

        assertFalse(blog.paused());

        vm.expectEmit(false, false, false, true);
        emit Paused(address(this));

        blog.pause();
        assertTrue(blog.paused());

        vm.expectEmit(false, false, false, true);
        emit Unpaused(address(this));

        blog.unpause();
        assertFalse(blog.paused());
    }

    function testRevert_notOwner_unpause() public {
        blog.pause();
        assertTrue(blog.paused());

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        
        blog.unpause();
    }

    function testRevert_unpause_whenNotPaused() public {
        assertFalse(blog.paused());

        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        blog.unpause();
    }

    function testRevert_withdrawFunction_revertsWithData() public {
        vm.deal(address(blog), 1 ether);
        assertEq(blog.balance(), 1 ether);

        RevertingReceiver revertingReceiver = new RevertingReceiver();

        vm.expectRevert("Reverted Data");
        blog.withdraw(payable(address(revertingReceiver)));

        assertEq(address(revertingReceiver).balance, 0);
        assertEq(blog.balance(), 1 ether);
    }

    function testRevert_withdrawFunction_revertsNoData() public {
        vm.deal(address(blog), 1 ether);
        assertEq(blog.balance(), 1 ether);

        SilentRejector silentRejector = new SilentRejector();

        vm.expectRevert(IBlog.WithdrawalFailedNoData.selector);
        blog.withdraw(payable(address(silentRejector)));

        assertEq(address(silentRejector).balance, 0);
        assertEq(blog.balance(), 1 ether);
    }
}