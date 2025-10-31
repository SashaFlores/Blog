// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from 'forge-std/Test.sol';
import { StdInvariant } from 'forge-std/StdInvariant.sol';
import { UnsafeUpgrades } from 'openzeppelin-foundry-upgrades/Upgrades.sol';
import { Blog } from 'src/Blog.sol';

error LessThanPremiumFee(uint256 requiredFee);
error EnforcedPause();
error EmptyBalance();
error NonTransferrable();

contract BlogHandler is Test {
    Blog internal blog;
    address internal owner;

    mapping(address => uint256) private standardBalance;
    mapping(address => uint256) private premiumBalance;

    address[] private standardHolders;
    address[] private premiumHolders;

    mapping(address => bool) private isStandardHolder;
    mapping(address => bool) private isPremiumHolder;

    uint256 public totalPremiumMinted;
    uint256 public totalStandardMinted;
    uint256 public trackedBalance;

    bool public pauseMintViolation;
    bool public pauseTransferViolation;
    bool public premiumTransferViolation;

    constructor(Blog blog_, address owner_) {
        blog = blog_;
        owner = owner_;
    }

    function mintStandard(uint256 seed) external {
        address user = _addrFromSeed(seed, 'standard');
        uint256 donation = bound(uint256(keccak256(abi.encode(seed, 'donation'))), 0, 5 ether);
        bool pausedBefore = blog.paused();

        vm.deal(user, donation);

        vm.startPrank(user);
        bool success;
        bytes memory err;
        try blog.mint{ value: donation }() {
            success = true;
        } catch (bytes memory reason) {
            success = false;
            err = reason;
        }
        vm.stopPrank();

        if (success) {
            if (pausedBefore) pauseMintViolation = true;
            _noteStandardMint(user, 1);
            trackedBalance += donation;
        } else {
            if (!pausedBefore || !_matchesSelector(err, EnforcedPause.selector)) {
                fail('unexpected revert on mintStandard');
            }
        }
    }

    function mintPremium(uint256 seed, string calldata tokenURI) external {
        address user = _addrFromSeed(seed, 'premium');
        string memory sanitized = _sanitizeURI(tokenURI, seed);
        uint256 fee = blog.getPremiumFee();
        uint256 extra = bound(uint256(keccak256(abi.encode(seed, 'premium-extra'))), 0, 5 ether);
        uint256 payment = fee + extra;
        bool pausedBefore = blog.paused();

        vm.deal(user, payment);

        vm.startPrank(user);
        bool success;
        bytes memory err;
        try blog.mintPremium{ value: payment }(sanitized) {
            success = true;
        } catch (bytes memory reason) {
            success = false;
            err = reason;
        }
        vm.stopPrank();

        if (success) {
            if (pausedBefore) pauseMintViolation = true;
            _increasePremiumBalance(user, 1);
            trackedBalance += payment;
        } else {
            if (!pausedBefore || !_matchesSelector(err, EnforcedPause.selector)) {
                fail('unexpected revert on mintPremium');
            }
        }
    }

    function transferStandard(uint256 holderSeed, address toSeed, uint256 amountSeed) external {
        address from = _selectStandardHolder(holderSeed);
        if (from == address(0)) return;

        uint256 available = standardBalance[from];
        if (available == 0) return;

        address to = _addrFromSeed(uint256(uint160(toSeed)) + holderSeed, 'standard-recipient');
        if (to == address(0)) {
            to = address(0x1);
        }

        if (to == from) {
            to = address(uint160(uint256(keccak256(abi.encode(holderSeed, to)))));
            if (to == address(0)) to = address(0x2);
        }

        uint256 amount = bound(amountSeed, 1, available);
        bool pausedBefore = blog.paused();

        vm.startPrank(from);
        bool success;
        bytes memory err;
        try blog.safeTransferFrom(from, to, uint256(blog.STANDARD()), amount, '') {
            success = true;
        } catch (bytes memory reason) {
            success = false;
            err = reason;
        }
        vm.stopPrank();

        if (success) {
            if (pausedBefore) pauseTransferViolation = true;
            _decreaseStandardBalance(from, amount);
            _addStandardBalance(to, amount);
        } else {
            if (!pausedBefore || !_matchesSelector(err, EnforcedPause.selector)) {
                fail('unexpected revert on transferStandard');
            }
        }
    }

    function attemptTransferPremium(uint256 holderSeed, address toSeed, uint256 amountSeed) external {
        uint256 holders = premiumHolders.length;
        if (holders == 0) return;

        address from = premiumHolders[holderSeed % holders];
        uint256 minted = premiumBalance[from];
        if (minted == 0) return;

        address to = _addrFromSeed(uint256(uint160(toSeed)) + holderSeed, 'premium-recipient');
        if (to == address(0)) to = address(0x1);
        if (to == from) {
            to = address(uint160(uint256(keccak256(abi.encode(holderSeed, to)))));
            if (to == address(0)) to = address(0x2);
        }

        uint256 amount = bound(amountSeed, 1, minted);
        bool pausedBefore = blog.paused();

        vm.startPrank(from);
        bool success;
        try blog.safeTransferFrom(from, to, uint256(blog.PREMIUM()), amount, '') {
            success = true;
        } catch {
            success = false;
        }
        vm.stopPrank();

        if (success) {
            premiumTransferViolation = true;
            if (pausedBefore) pauseTransferViolation = true;
        }
    }

    function togglePause(uint256 seed) external {
        bool wantPause = (seed & 1) == 1;
        bool paused = blog.paused();

        if (wantPause && !paused) {
            vm.prank(owner);
            blog.pause();
        } else if (!wantPause && paused) {
            vm.prank(owner);
            blog.unpause();
        }
    }

    function withdraw(uint256 seed) external {
        if (trackedBalance == 0) return;

        address recipient = _addrFromSeed(seed, 'withdraw');
        if (recipient == address(0)) recipient = address(0x1);

        vm.startPrank(owner);
        bool success;
        bytes memory err;
        try blog.withdraw(payable(recipient)) {
            success = true;
        } catch (bytes memory reason) {
            success = false;
            err = reason;
        }
        vm.stopPrank();

        if (success) {
            trackedBalance = 0;
        } else {
            if (!_matchesSelector(err, EmptyBalance.selector)) {
                fail('unexpected revert on withdraw');
            }
        }
    }

    function premiumHoldersLength() external view returns (uint256) {
        return premiumHolders.length;
    }

    function premiumHolderAt(uint256 index) external view returns (address) {
        return premiumHolders[index];
    }

    function premiumMinted(address account) external view returns (uint256) {
        return premiumBalance[account];
    }

    function _noteStandardMint(address user, uint256 amount) private {
        if (!isStandardHolder[user]) {
            isStandardHolder[user] = true;
            standardHolders.push(user);
        }
        standardBalance[user] += amount;
        totalStandardMinted += amount;
    }

    function _addStandardBalance(address user, uint256 amount) private {
        if (amount == 0) return;
        if (!isStandardHolder[user]) {
            isStandardHolder[user] = true;
            standardHolders.push(user);
        }
        standardBalance[user] += amount;
    }

    function _decreaseStandardBalance(address user, uint256 amount) private {
        if (standardBalance[user] >= amount) {
            standardBalance[user] -= amount;
        } else {
            standardBalance[user] = 0;
        }
    }

    function _increasePremiumBalance(address user, uint256 amount) private {
        if (!isPremiumHolder[user]) {
            isPremiumHolder[user] = true;
            premiumHolders.push(user);
        }
        premiumBalance[user] += amount;
        totalPremiumMinted += amount;
    }

    function _selectStandardHolder(uint256 seed) private view returns (address) {
        uint256 length = standardHolders.length;
        if (length == 0) return address(0);
        uint256 start = seed % length;
        for (uint256 i = 0; i < length; ++i) {
            address candidate = standardHolders[(start + i) % length];
            if (standardBalance[candidate] > 0) {
                return candidate;
            }
        }
        return address(0);
    }

    function _sanitizeURI(string memory raw, uint256 seed) private pure returns (string memory) {
        bytes memory data = bytes(raw);
        if (data.length == 0) {
            return _buildUriFromSeed(seed);
        }
        if (data.length > 2048) {
            bytes memory trimmed = new bytes(2048);
            for (uint256 i = 0; i < 2048; ++i) {
                trimmed[i] = data[i];
            }
            return string(trimmed);
        }
        return raw;
    }

    function _buildUriFromSeed(uint256 seed) private pure returns (string memory) {
        bytes memory output = new bytes(64);
        for (uint256 i = 0; i < 64; ++i) {
            output[i] = bytes1(uint8(65 + (uint256(keccak256(abi.encode(seed, i))) % 26)));
        }
        return string(output);
    }

    function _addrFromSeed(uint256 seed, string memory tag) private pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(seed, tag)))));
    }

    function _matchesSelector(bytes memory err, bytes4 selector) private pure returns (bool) {
        if (err.length < 4) return false;
        bytes4 actual;
        assembly {
            actual := mload(add(err, 0x20))
        }
        return actual == selector;
    }
}

contract BlogInvariants is Test {
    Blog internal blog;
    BlogHandler internal handler;

    address internal owner;
    uint256 internal constant PREMIUM_FEE = 0.05 ether;
    string internal baseURI = 'https://example.com/metadata/';

    function setUp() public virtual {
        owner = makeAddr('owner');

        address implementation = address(new Blog());
        address proxy = UnsafeUpgrades.deployUUPSProxy(
            implementation,
            abi.encodeCall(Blog.__Blog_init, (owner, PREMIUM_FEE, baseURI))
        );

        blog = Blog(payable(proxy));
        handler = new BlogHandler(blog, owner);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = BlogHandler.mintStandard.selector;
        selectors[1] = BlogHandler.mintPremium.selector;
        selectors[2] = BlogHandler.transferStandard.selector;
        selectors[3] = BlogHandler.attemptTransferPremium.selector;
        selectors[4] = BlogHandler.togglePause.selector;
        selectors[5] = BlogHandler.withdraw.selector;
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    }

    function invariant_totalSupplyIntegrity() public view {
        uint256 standardId = uint256(blog.STANDARD());
        uint256 premiumId = uint256(blog.PREMIUM());

        assertEq(blog.totalSupply(standardId), handler.totalStandardMinted(), 'standard supply mismatch');
        assertEq(blog.totalSupply(premiumId), handler.totalPremiumMinted(), 'premium supply mismatch');
    }

    function invariant_premiumNonTransferable() public view {
        uint256 premiumId = uint256(blog.PREMIUM());
        uint256 length = handler.premiumHoldersLength();

        uint256 trackedTotal;
        for (uint256 i = 0; i < length; ++i) {
            address holder = handler.premiumHolderAt(i);
            uint256 expected = handler.premiumMinted(holder);
            if (expected == 0) continue;

            uint256 actual = blog.balanceOf(holder, premiumId);
            assertEq(actual, expected, 'premium balance mismatch');
            trackedTotal += expected;
        }

        assertEq(trackedTotal, handler.totalPremiumMinted(), 'premium accounting mismatch');
        assertFalse(handler.premiumTransferViolation(), 'premium transfer succeeded');
    }

    function invariant_feeNonZero() public view {
        assertTrue(blog.getPremiumFee() != 0, 'premium fee zero');
    }

    function invariant_balanceAccounting() public view {
        assertEq(blog.balance(), handler.trackedBalance(), 'contract balance mismatch');
    }

    function invariant_pauseEnforcement() public view {
        assertFalse(handler.pauseMintViolation(), 'mint succeeded while paused');
        assertFalse(handler.pauseTransferViolation(), 'transfer succeeded while paused');
    }
}
