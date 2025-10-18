// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { RevertingReceiver } from '../mocks/RevertingReceiver.sol';
import { SilentRejector } from '../mocks/SilentRejector.sol';
import { Setup } from './Setup.t.sol';
import { console } from 'forge-std/Script.sol';
import { UnsafeUpgrades } from 'openzeppelin-foundry-upgrades/Upgrades.sol';

error OwnableUnauthorizedAccount(address account);

error OwnableInvalidOwner(address owner);

error InvalidNewFee();

error EmptyBalance();

error EnforcedPause();

error ExpectedPause();

error WithdrawalFailedNoData();

error EmptyURI();

event FundsWithdrawn(address indexed recipient, uint256 amount);

event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

event Paused(address account);

event Unpaused(address account);

contract Owner is Setup {

    function test_initialOwner() public view {
        assertEq(blog.owner(), msg.sender);
    }

    function test_premiumFee() public view {
        assertEq(blog.getPremiumFee(), premiumFee);
    }

    function testRevert_transferOwnership_toZeroAddress() public {
        vm.prank(msg.sender);
        vm.expectRevert(abi.encodeWithSelector(OwnableInvalidOwner.selector, address(0x00)));
        blog.transferOwnership(address(0x00));
    }

    function testEmits_whenOwner_transferOwnership_elseReverts() public {
        // notOwner -> msg.sender `owner`
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, notOwner));
        blog.transferOwnership(msg.sender);
        assertEq(blog.owner(), msg.sender);

        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(msg.sender, notOwner);

        vm.prank(msg.sender);
        blog.transferOwnership(notOwner);
        assertEq(blog.owner(), notOwner);
    }

    function testEmits_ownershipTransferred_whenOwnerRenounces() public {
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, notOwner));
        blog.renounceOwnership();
        assertTrue(blog.owner() == msg.sender);

        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(msg.sender, address(0));

        vm.prank(msg.sender);
        blog.renounceOwnership();
        assertEq(blog.owner(), address(0));
    }

    function test_onlyOwnerFunctions_changeFee() public {
        assertEq(blog.getPremiumFee(), premiumFee);

        uint256 newFee = 0.02 ether;

        vm.prank(msg.sender);
        blog.updatePremiumFee(newFee);

        assertEq(blog.getPremiumFee(), newFee);

        // not owner reverts
        uint256 notOwnerFee = 1 ether;
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, notOwner));
        vm.prank(notOwner);
        blog.updatePremiumFee(notOwnerFee);

        assertEq(blog.getPremiumFee(), newFee);
    }

    function testRevert_onlyOwnerChangeURI() public {
        assertEq(blog.uri(0), URI);

        string memory newURI = 'https://new.example.com/metadata/';

        vm.prank(notOwner);

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, notOwner));
        blog.modifyURI(newURI);
    }

    function test_onlyOwner_withdrawsFunds() public {
        vm.deal(address(blog), 1 ether);
        assertEq(blog.balance(), 1 ether);

        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(notOwner, 1 ether);

        vm.prank(msg.sender);
        blog.withdraw(payable(notOwner));

        assertEq(notOwner.balance, 1 ether);
        assertEq(blog.balance(), 0);

        vm.deal(address(blog), 10 ether);

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, notOwner));
        blog.withdraw(payable(notOwner));

        assertEq(blog.balance(), 10 ether);
    }

    function test_whenPaused_ownerCanWithdrawAndChangeFee() public {
        assertEq(blog.getPremiumFee(), premiumFee);

        vm.deal(address(blog), 1 ether);
        assertEq(blog.balance(), 1 ether);

        vm.startPrank(msg.sender);

        blog.pause();
        assertTrue(blog.paused());

        blog.withdraw(payable(notOwner));
        assertEq(notOwner.balance, 1 ether);

        uint256 newFee = 5 ether;
        blog.updatePremiumFee(newFee);
        assertEq(blog.getPremiumFee(), newFee);

        vm.stopPrank();
    }

    function testRevert_whenNewFeeIsZero_orEqualExisting() public {
        assertEq(blog.getPremiumFee(), premiumFee);

        vm.startPrank(msg.sender);

        vm.expectRevert(InvalidNewFee.selector);
        blog.updatePremiumFee(0);
        assertEq(blog.getPremiumFee(), premiumFee);

        vm.expectRevert(InvalidNewFee.selector);
        blog.updatePremiumFee(premiumFee);
        assertEq(blog.getPremiumFee(), premiumFee);

        vm.stopPrank();
    }

    function testRevert_withdrawFunction_whenBalanceIsZero() public {
        assertEq(blog.balance(), 0);

        vm.prank(msg.sender);

        vm.expectRevert(EmptyBalance.selector);
        blog.withdraw(payable(notOwner));

        assertEq(notOwner.balance, 0);
        assertEq(blog.balance(), 0);
    }

    function testEmits_pausedEvent_whenOwnerPause_elseReverts() public {
        assertFalse(blog.paused());

        vm.expectEmit(false, false, false, true);
        emit Paused(msg.sender);

        vm.prank(msg.sender);
        blog.pause();
        assertTrue(blog.paused());

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, notOwner));
        blog.unpause();
        assertTrue(blog.paused());

        vm.expectEmit(false, false, false, true);
        emit Unpaused(msg.sender);

        vm.prank(msg.sender);
        blog.unpause();
        assertFalse(blog.paused());
    }

    function testRevert_unpause_whenNotPaused() public {
        assertFalse(blog.paused());

        vm.startPrank(msg.sender);
        // paused
        blog.pause();
        assertTrue(blog.paused());

        // pause gain
        vm.expectRevert(EnforcedPause.selector);
        blog.pause();

        // unpause
        assertTrue(blog.paused());
        blog.unpause();

        assertFalse(blog.paused());
        vm.expectRevert(ExpectedPause.selector);
        blog.unpause();

        vm.stopPrank();
    }

    function testRevert_withdrawFunction_revertsWithData() public {
        vm.deal(address(blog), 1 ether);
        assertEq(blog.balance(), 1 ether);

        RevertingReceiver revertingReceiver = new RevertingReceiver();

        vm.prank(msg.sender);

        vm.expectRevert('Reverted Data');
        blog.withdraw(payable(address(revertingReceiver)));

        assertEq(address(revertingReceiver).balance, 0);
        assertEq(blog.balance(), 1 ether);
    }

    function testRevert_withdrawFunction_revertsNoData() public {
        vm.deal(address(blog), 1 ether);
        assertEq(blog.balance(), 1 ether);

        SilentRejector silentRejector = new SilentRejector();

        vm.prank(msg.sender);
        vm.expectRevert(WithdrawalFailedNoData.selector);
        blog.withdraw(payable(address(silentRejector)));

        assertEq(address(silentRejector).balance, 0);
        assertEq(blog.balance(), 1 ether);
    }

    function testRevert_whenURI_empty() public {
        vm.prank(msg.sender);

        vm.expectRevert(EmptyURI.selector);
        blog.modifyURI('');
    }

}
