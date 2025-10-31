// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Setup } from './Setup.t.sol';


error NonTransferrable();

error EnforcedPause();

error LessThanPremiumFee(uint256 requiredFee);

event FundsReceived(address indexed sender, uint256 amount);

event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

event PremiumReceived(address indexed sender, string tokenURI);

contract Balances is Setup {

    function test_mintStandard_withDonation() public {
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(standardUser, address(0x00), standardUser, uint256(blog.STANDARD()), 1);

        vm.expectEmit(true, false, false, true);
        emit FundsReceived(standardUser, 0.01 ether);

        vm.prank(standardUser);
        vm.deal(standardUser, 0.01 ether);

        blog.mint{ value: 0.01 ether }();

        assertEq(blog.balance(), 0.01 ether);
        assertEq(blog.balanceOf(standardUser, uint256(blog.STANDARD())), 1);
        assertEq(blog.totalSupply(uint256(blog.STANDARD())), 1);
    }

    function test_mintStandard_free() public {
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(standardUser, address(0x00), standardUser, uint256(blog.STANDARD()), 1);

        vm.prank(standardUser);
        blog.mint();

        assertEq(blog.balanceOf(standardUser, uint256(blog.STANDARD())), 1);
        assertEq(blog.balance(), 0 ether);
        assertEq(blog.totalSupply(uint256(blog.STANDARD())), 1);
    }

    function testRevert_mintPremium_withoutFee() public {
        vm.expectRevert(abi.encodeWithSelector(LessThanPremiumFee.selector, premiumFee));

        vm.prank(standardUser);
        blog.mintPremium('https://example.com/metadata/premium');

        assertEq(blog.balance(), 0 ether);
        assertEq(blog.balanceOf(standardUser, uint256(blog.PREMIUM())), 0);
    }

    function test_emitsRightURIEvent_premiumToken() public {
        vm.expectEmit(true, true, false, true);
        emit TransferSingle(premiumUser, address(0x00), premiumUser, uint256(blog.PREMIUM()), 1);

        vm.expectEmit(true, false, false, true);
        emit PremiumReceived(
            premiumUser, 'https://www.sashaflores.xyz/articles/optimization-of-gas-and-bytecode-limitation'
        );

        vm.prank(premiumUser);
        vm.deal(premiumUser, 1 ether);

        blog.mintPremium{ value: 1 ether }(
            'https://www.sashaflores.xyz/articles/optimization-of-gas-and-bytecode-limitation'
        );

        assertEq(blog.balanceOf(premiumUser, uint256(blog.PREMIUM())), 1);
        assertEq(blog.balance(), 1 ether);
    }

    function testRevert_mintPremium_lessThanRequiredFee() public {
        vm.expectRevert(abi.encodeWithSelector(LessThanPremiumFee.selector, premiumFee));

        vm.prank(premiumUser);
        vm.deal(premiumUser, 0.01 ether);
        blog.mintPremium('https://example.com/metadata/premium');

        assertEq(blog.balanceOf(premiumUser, uint256(blog.PREMIUM())), 0);
        assertEq(blog.balance(), 0 ether);
    }

    function testRevert_whenPaused_mintDisabled() public {
        vm.prank(msg.sender);

        blog.pause();
        assertTrue(blog.paused());

        vm.expectRevert(EnforcedPause.selector);

        vm.prank(standardUser);
        blog.mint();

        assertEq(blog.balanceOf(standardUser, uint256(blog.STANDARD())), 0);

        vm.expectRevert(EnforcedPause.selector);

        vm.prank(premiumUser);
        vm.deal(premiumUser, 1 ether);

        blog.mintPremium{ value: premiumFee }('https://example.com/metadata/premium');
        assertEq(blog.balanceOf(premiumUser, uint256(blog.PREMIUM())), 0);

        vm.prank(msg.sender);

        blog.unpause();
        assertFalse(blog.paused());

        vm.prank(standardUser);
        blog.mint();
        assertEq(blog.balanceOf(standardUser, uint256(blog.STANDARD())), 1);
    }

    function test_totalSupply_contractBalance() public {
        vm.deal(premiumUser, 3 ether);
        vm.startPrank(premiumUser);

        blog.mintPremium{ value: premiumFee }('https://example.com/metadata/premium');
        blog.mintPremium{ value: premiumFee }('https://example.com/metadata/premium');
        blog.mintPremium{ value: premiumFee }('https://example.com/metadata/premium');

        assertEq(blog.totalSupply(uint256(blog.PREMIUM())), 3);
        assertEq(blog.balanceOf(premiumUser, uint256(blog.PREMIUM())), 3);
        uint256 totalPremiumReceived = premiumFee * 3;
        assertEq(blog.balance(), totalPremiumReceived);
        vm.stopPrank();

        vm.startPrank(standardUser);
        vm.deal(standardUser, 1 ether);
        uint256 donation = 1 ether;
        blog.mint{ value: donation }();
        blog.mint();
        blog.mint();
        blog.mint();
        assertEq(blog.totalSupply(uint256(blog.STANDARD())), 4);
        assertEq(blog.balanceOf(standardUser, uint256(blog.STANDARD())), 4);
        uint256 totalReceived = totalPremiumReceived + donation;
        assertEq(blog.balance(), totalReceived);
        vm.stopPrank();
    }

    function test_transferrable_StandardToken() public {
        vm.startPrank(standardUser);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(standardUser, address(0x00), standardUser, uint256(blog.STANDARD()), 1);
        blog.mint();

        assertEq(blog.balanceOf(standardUser, uint256(blog.STANDARD())), 1);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(standardUser, standardUser, notOwner, uint256(blog.STANDARD()), 1);
        blog.safeTransferFrom(standardUser, notOwner, uint256(blog.STANDARD()), 1, '');

        assertEq(blog.balanceOf(standardUser, uint256(blog.STANDARD())), 0);
        assertEq(blog.balanceOf(notOwner, uint256(blog.STANDARD())), 1);

        vm.stopPrank();
    }

    /// forge-config: default.allow_internal_expect_revert = true
    //   function testRevert_nonTransferrable_premiumToken() public {
    //     vm.startPrank(premiumUser);
    //     vm.deal(premiumUser, 1 ether);
    //     blog.mintPremium{value: premiumFee}(URI);
    //     assertEq(blog.balanceOf(premiumUser, uint256(blog.PREMIUM())), 1);

    //     vm.expectRevert(NonTransferrable.selector);
    //     blog.safeTransferFrom(premiumUser, notOwner, uint256(blog.PREMIUM()), 1, "");

    //     assertEq(blog.balanceOf(standardUser, uint256(blog.PREMIUM())), 1);
    //     assertEq(blog.balanceOf(notOwner, uint256(blog.PREMIUM())), 0);

    //     vm.stopPrank();
    //   }

    //   function testRevert_whenPaused_noTransfer_StandardToken() public {
    //     vm.prank(standardUser);
    //     blog.mint();
    //     assertEq(blog.balanceOf(standardUser, uint256(blog.STANDARD())), 1);

    //     vm.prank(msg.sender);
    //     blog.pause();
    //     assertTrue(blog.paused());

    //     vm.startPrank(standardUser);
    //     vm.expectRevert(EnforcedPause.selector);
    //     blog.safeTransferFrom(standardUser, notOwner, uint256(blog.STANDARD()), 1, "");

    //     assertEq(blog.balanceOf(standardUser, uint256(blog.STANDARD())), 1);
    //     assertEq(blog.balanceOf(notOwner, uint256(blog.STANDARD())), 0);
    //     vm.stopPrank();
    //   }

    function test_receiveFunctionBalance_emitsEvent() public {
        hoax(notOwner, 5 ether);

        vm.expectEmit(true, false, false, true);
        emit FundsReceived(notOwner, 3 ether);

        (bool received,) = payable(address(blog)).call{ value: 3 ether }('');
        assertTrue(received);
        assertEq(address(blog).balance, 3 ether);
        assertEq(blog.balance(), 3 ether);
        assertEq(notOwner.balance, 2 ether);
    }

}
