// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from 'forge-std/Test.sol';
import { UnsafeUpgrades } from 'openzeppelin-foundry-upgrades/Upgrades.sol';
import { Blog } from 'src/Blog.sol';

error LessThanPremiumFee(uint256 requiredFee);
error EnforcedPause();
error InvalidNewFee();
error EmptyURI();
error NonTransferrable();

event PremiumReceived(address indexed sender, string tokenURI);
event FundsWithdrawn(address indexed recipient, uint256 amount);

contract BlogFuzz is Test {
    Blog internal blog;

    address internal owner;
    address internal standardUser;
    address internal premiumUser;
    address internal notOwner;

    uint256 internal premiumFee = 0.05 ether;
    string internal baseURI = 'https://example.com/metadata/';

    function setUp() public {
        owner = makeAddr('owner');
        standardUser = makeAddr('standardUser');
        premiumUser = makeAddr('premiumUser');
        notOwner = makeAddr('notOwner');

        address implementation = address(new Blog());
        address proxy = UnsafeUpgrades.deployUUPSProxy(
            implementation,
            abi.encodeCall(Blog.__Blog_init, (owner, premiumFee, baseURI))
        );

        blog = Blog(payable(proxy));
    }

    function testFuzz_updatePremiumFee_behaviour(uint256 newFee) public {
        vm.startPrank(owner);
        if (newFee == 0 || newFee == premiumFee) {
            vm.expectRevert(InvalidNewFee.selector);
            blog.updatePremiumFee(newFee);
        } else {
            blog.updatePremiumFee(newFee);
            assertEq(blog.getPremiumFee(), newFee);

            vm.expectRevert(InvalidNewFee.selector);
            blog.updatePremiumFee(newFee);
        }
        vm.stopPrank();
    }

    function testFuzz_modifyUri_handlesEmptyAndNonEmpty(bytes calldata rawBytes, bool forceEmpty) public {
        bytes memory candidateBytes = rawBytes;
        if (candidateBytes.length > 4096) {
            bytes memory trimmed = new bytes(4096);
            for (uint256 i = 0; i < 4096; ++i) {
                trimmed[i] = candidateBytes[i];
            }
            candidateBytes = trimmed;
        }

        string memory candidate = string(candidateBytes);
        if (forceEmpty || bytes(candidate).length == 0) {
            vm.prank(owner);
            vm.expectRevert(EmptyURI.selector);
            blog.modifyUri('');
        } else {
            vm.prank(owner);
            blog.modifyUri(candidate);
            assertEq(blog.uri(uint256(blog.STANDARD())), candidate);
        }
    }

    function testFuzz_mintStandard_acceptsAnyDonation(uint256 donation) public {
        uint256 amount = bound(donation, 0, 100 ether);

        vm.deal(standardUser, amount);

        vm.prank(standardUser);
        blog.mint{ value: amount }();

        uint256 standardId = uint256(blog.STANDARD());

        assertEq(blog.balanceOf(standardUser, standardId), 1);
        assertEq(blog.totalSupply(standardId), 1);
        assertEq(blog.balance(), amount);
    }

    function testFuzz_mintPremium_acceptsValueAtOrAboveFee(
        uint96 payment,
        string calldata tokenURI
    ) public {
        uint256 sendValue = bound(uint256(payment), premiumFee, premiumFee + 100 ether);

        vm.deal(premiumUser, sendValue);

        vm.prank(premiumUser);
        blog.mintPremium{ value: sendValue }(tokenURI);

        uint256 premiumId = uint256(blog.PREMIUM());

        assertEq(blog.balanceOf(premiumUser, premiumId), 1);
        assertEq(blog.totalSupply(premiumId), 1);
        assertEq(blog.balance(), sendValue);
    }

    function testFuzz_reverts_mintPremium_belowFee(
        uint96 payment,
        string calldata tokenURI
    ) public {
        uint256 sendValue = bound(uint256(payment), 0, premiumFee == 0 ? 0 : premiumFee - 1);

        vm.deal(premiumUser, sendValue);

        vm.prank(premiumUser);
        vm.expectRevert(abi.encodeWithSelector(LessThanPremiumFee.selector, premiumFee));
        blog.mintPremium{ value: sendValue }(tokenURI);
    }

    function testFuzz_standardTransfersMaintainAccounting(
        uint256 senderSeed,
        uint256 recipientSeed,
        uint8 mintCount,
        uint8 transferAmount
    ) public {
        vm.assume(senderSeed != recipientSeed);

        address sender = _userFromSeed(senderSeed, 'sender');
        address recipient = _userFromSeed(recipientSeed, 'recipient');

        vm.assume(sender != address(0));
        vm.assume(recipient != address(0));
        vm.assume(sender != recipient);

        uint256 minted = bound(uint256(mintCount), 1, 25);
        uint256 transferQty = bound(uint256(transferAmount), 1, minted);
        uint256 standardId = uint256(blog.STANDARD());

        vm.startPrank(sender);
        for (uint256 i = 0; i < minted; ++i) {
            blog.mint();
        }
        vm.stopPrank();

        assertEq(blog.balanceOf(sender, standardId), minted);
        uint256 supplyBefore = blog.totalSupply(standardId);

        vm.prank(sender);
        blog.safeTransferFrom(sender, recipient, standardId, transferQty, '');

        assertEq(blog.balanceOf(sender, standardId), minted - transferQty);
        assertEq(blog.balanceOf(recipient, standardId), transferQty);
        assertEq(blog.totalSupply(standardId), supplyBefore);
    }

    function testFuzz_batchStandardTransfersMaintainAccounting(
        uint8 lengthSeed,
        bytes32 amountSeed
    ) public {
        uint256 length = bound(uint256(lengthSeed), 1, 5);
        uint256 standardId = uint256(blog.STANDARD());

        uint256[] memory ids = new uint256[](length);
        uint256[] memory amounts = new uint256[](length);
        uint256 totalToTransfer;
        for (uint256 i = 0; i < length; ++i) {
            ids[i] = standardId;
            uint256 amount = 1 + (uint256(keccak256(abi.encode(amountSeed, i))) % 3);
            amounts[i] = amount;
            totalToTransfer += amount;
        }

        vm.startPrank(standardUser);
        for (uint256 i = 0; i < totalToTransfer; ++i) {
            blog.mint();
        }
        vm.stopPrank();

        uint256 supplyBefore = blog.totalSupply(standardId);
        uint256 recipientBefore = blog.balanceOf(notOwner, standardId);

        vm.prank(standardUser);
        blog.safeBatchTransferFrom(standardUser, notOwner, ids, amounts, '');

        assertEq(blog.balanceOf(standardUser, standardId), 0);
        assertEq(blog.balanceOf(notOwner, standardId), recipientBefore + totalToTransfer);
        assertEq(blog.totalSupply(standardId), supplyBefore);
    }

    function testFuzz_pauseSequence_blocksMintsWhenPaused(
        uint256 actionMask,
        uint256 donationSeed,
        uint256 premiumSeed
    ) public {
        bool paused = blog.paused();
        assertFalse(paused);

        uint256 standardId = uint256(blog.STANDARD());
        uint256 premiumId = uint256(blog.PREMIUM());

        uint256 expectedStandardBalance = blog.balanceOf(standardUser, standardId);
        uint256 expectedPremiumBalance = blog.balanceOf(premiumUser, premiumId);
        uint256 expectedStandardSupply = blog.totalSupply(standardId);
        uint256 expectedPremiumSupply = blog.totalSupply(premiumId);
        uint256 expectedContractBalance = blog.balance();

        for (uint256 step = 0; step < 16; ++step) {
            uint256 action = (actionMask >> (step * 2)) & 0x3;

            if (action == 0) {
                if (!paused) {
                    vm.prank(owner);
                    blog.pause();
                    paused = true;
                }
            } else if (action == 1) {
                if (paused) {
                    vm.prank(owner);
                    blog.unpause();
                    paused = false;
                }
            } else if (action == 2) {
                uint256 donation = bound(
                    uint256(keccak256(abi.encode(donationSeed, step, 'donation'))),
                    0,
                    5 ether
                );

                vm.deal(standardUser, donation);
                vm.startPrank(standardUser);
                if (paused) {
                    vm.expectRevert(EnforcedPause.selector);
                    blog.mint{ value: donation }();
                } else {
                    blog.mint{ value: donation }();
                    expectedStandardBalance += 1;
                    expectedStandardSupply += 1;
                    expectedContractBalance += donation;
                }
                vm.stopPrank();

                assertEq(blog.balanceOf(standardUser, standardId), expectedStandardBalance);
                assertEq(blog.totalSupply(standardId), expectedStandardSupply);
                assertEq(blog.balance(), expectedContractBalance);
            } else {
                uint256 extra = bound(
                    uint256(keccak256(abi.encode(premiumSeed, step, 'extra'))),
                    0,
                    5 ether
                );
                uint256 payment = premiumFee + extra;

                vm.deal(premiumUser, payment);
                vm.startPrank(premiumUser);
                if (paused) {
                    vm.expectRevert(EnforcedPause.selector);
                    blog.mintPremium{ value: payment }('pause-test');
                } else {
                    blog.mintPremium{ value: payment }('pause-test');
                    expectedPremiumBalance += 1;
                    expectedPremiumSupply += 1;
                    expectedContractBalance += payment;
                }
                vm.stopPrank();

                assertEq(blog.balanceOf(premiumUser, premiumId), expectedPremiumBalance);
                assertEq(blog.totalSupply(premiumId), expectedPremiumSupply);
                assertEq(blog.balance(), expectedContractBalance);
            }
        }

        assertEq(blog.paused(), paused);
    }

    function testFuzz_premiumTransfersAlwaysRevert(uint8 lengthSeed) public {
        uint256 length = bound(uint256(lengthSeed), 1, 5);
        uint256 premiumId = uint256(blog.PREMIUM());
        uint256 standardId = uint256(blog.STANDARD());

        uint256[] memory ids = new uint256[](length);
        uint256[] memory amounts = new uint256[](length);

        uint256 premiumCount;
        uint256 standardCount;
        for (uint256 i = 0; i < length; ++i) {
            bool isPremium = ((uint256(keccak256(abi.encode(lengthSeed, i))) & 1) == 1);
            if (i == length - 1) {
                isPremium = true;
            }
            ids[i] = isPremium ? premiumId : standardId;
            amounts[i] = 1;
            if (isPremium) {
                premiumCount += 1;
            } else {
                standardCount += 1;
            }
        }

        vm.deal(premiumUser, premiumFee * premiumCount + 1 ether);

        vm.startPrank(premiumUser);
        for (uint256 i = 0; i < premiumCount; ++i) {
            blog.mintPremium{ value: premiumFee }('premium');
        }
        for (uint256 i = 0; i < standardCount; ++i) {
            blog.mint();
        }
        vm.stopPrank();

        vm.prank(premiumUser);
        vm.expectRevert(NonTransferrable.selector);
        blog.safeBatchTransferFrom(premiumUser, notOwner, ids, amounts, '');
    }

    function testFuzz_withdrawAccumulatesAllDonations(
        uint256 donationAmount,
        uint256 premiumExtra
    ) public {
        address recipient = notOwner;

        uint256 standardDonation = bound(donationAmount, 0, 5 ether);
        uint256 extra = bound(premiumExtra, 0, 5 ether);
        uint256 premiumPayment = premiumFee + extra;

        vm.deal(standardUser, standardDonation);
        vm.prank(standardUser);
        blog.mint{ value: standardDonation }();

        vm.deal(premiumUser, premiumPayment);
        vm.prank(premiumUser);
        blog.mintPremium{ value: premiumPayment }('withdraw-test');

        uint256 expectedBalance = standardDonation + premiumPayment;
        assertEq(blog.balance(), expectedBalance);
        uint256 recipientBefore = recipient.balance;

        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(recipient, expectedBalance);

        vm.prank(owner);
        blog.withdraw(payable(recipient));

        assertEq(recipient.balance, recipientBefore + expectedBalance);
        assertEq(blog.balance(), 0);
    }

    function testFuzz_premiumUriEventEcho(uint96 extraPayment, string calldata tokenURI) public {
        vm.assume(bytes(tokenURI).length <= 2048);

        uint256 payment = premiumFee + bound(uint256(extraPayment), 0, 5 ether);

        _mintPremiumAndExpect(premiumUser, payment, tokenURI);
        _mintPremiumAndExpect(makeAddr('premium-empty-uri'), payment, '');

        string memory longUri = _buildLongUri(tokenURI);
        _mintPremiumAndExpect(makeAddr('premium-long-uri'), payment, longUri);
    }

    function _mintPremiumAndExpect(address user, uint256 payment, string memory tokenURI) private {
        uint256 premiumId = uint256(blog.PREMIUM());

        vm.deal(user, payment);

        vm.startPrank(user);
        uint256 balanceBefore = blog.balanceOf(user, premiumId);
        uint256 supplyBefore = blog.totalSupply(premiumId);
        uint256 contractBalanceBefore = blog.balance();

        vm.expectEmit(true, false, false, true);
        emit PremiumReceived(user, tokenURI);

        blog.mintPremium{ value: payment }(tokenURI);

        vm.stopPrank();

        assertEq(blog.balanceOf(user, premiumId), balanceBefore + 1);
        assertEq(blog.totalSupply(premiumId), supplyBefore + 1);
        assertEq(blog.balance(), contractBalanceBefore + payment);
    }

    function _buildLongUri(string memory seed) private pure returns (string memory) {
        bytes memory source = bytes(seed);

        uint256 targetLength = source.length;
        if (targetLength < 1024) targetLength = 1024;
        if (targetLength > 4096) targetLength = 4096;

        bytes memory output = new bytes(targetLength);
        for (uint256 i = 0; i < targetLength; ++i) {
            if (source.length == 0) {
                output[i] = bytes1(uint8(65 + (i % 26)));
            } else {
                output[i] = source[i % source.length];
            }
        }

        return string(output);
    }

    function _userFromSeed(uint256 seed, string memory tag) private pure returns (address) {
        address derived = address(uint160(uint256(keccak256(abi.encode(seed, tag)))));
        if (derived == address(0)) {
            return address(0x1);
        }
        return derived;
    }
}
