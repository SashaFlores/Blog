// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { MockMinter, MockMinterMissingHolder } from '../mocks/MockMinter.sol';
import { Initializable } from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import { PausableUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import { IERC1155Errors } from '@openzeppelin/contracts/interfaces/draft-IERC6093.sol';
import { Test, console } from 'forge-std/Test.sol';
import { Vm } from 'forge-std/Vm.sol';
import { Upgrades } from 'openzeppelin-foundry-upgrades/Upgrades.sol';
import { DeployBlog } from 'script/DeployBlog.s.sol';

import { BlogV2 } from 'script/mocks/BlogV2.sol';
import { Blog, IBlog } from 'src/Blog.sol';

event Upgraded(address indexed implementation);

event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

event Initialized(uint64 version);

event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

event Paused(address account);

event Unpaused(address account);

event FundsReceived(address indexed sender, uint256 amount);

event PremiumReceived(address indexed sender, string tokenURI);

event FundsWithdrawn(address indexed recipient, uint256 amount);

contract BlogTest is Test {

    Blog public blog;
    address public implementation;

    function setUp() external {
        vm.recordLogs();

        vm.createSelectFork(vm.rpcUrl('ethereum'));

        DeployBlog deployer = new DeployBlog();
        (address _proxy, address impl) = deployer.run();

        blog = Blog(payable(_proxy));
        implementation = impl;
    }

    // [x] test deployment of Blog contract
    // [x] test initial values of contract
    function testDeployment_Success() external view {
        address initialOwner = vm.envAddress('OWNER');

        assertEq(blog.version(), '1.0.0');
        assertEq(blog.contractName(), 'Blog');
        assertEq(blog.owner(), initialOwner);
    }

    // [x] check number of logs emitted in deployment
    // [x] check logs signatures
    // [x] check logs emitters' addresses
    // [x] check logs topic and data
    function testEventsEmittedInDeployment() external {
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 4);

        bytes32 upgradedEventSignature = keccak256('Upgraded(address)');
        bytes32 ownershipTransferredEventSignature = keccak256('OwnershipTransferred(address,address)');
        bytes32 initializedEventSignature = keccak256('Initialized(uint64)');

        assertEq(logs[0].topics[0], initializedEventSignature);
        assertEq(logs[1].topics[0], upgradedEventSignature);
        assertEq(logs[2].topics[0], ownershipTransferredEventSignature);
        assertEq(logs[3].topics[0], initializedEventSignature);

        assertEq(logs[0].emitter, implementation);
        assertEq(logs[1].emitter, address(blog));
        assertEq(logs[2].emitter, address(blog));
        assertEq(logs[3].emitter, address(blog));

        assertEq(abi.decode(logs[0].data, (uint64)), type(uint64).max);
        assertEq(logs[1].topics[1], bytes32(uint256(uint160((implementation)))));
        assertEq(logs[2].topics[1], bytes32(uint256(uint160(address(0x00)))));
        assertEq(logs[2].topics[2], bytes32(uint256(uint160(blog.owner()))));
        assertEq(abi.decode(logs[3].data, (uint64)), 1);
    }

    // [x] test re-initializing contract
    function tesReinitializingContract() external {
        address owner = blog.owner();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        blog.__Blog_init(owner, 1 ether, 'www.example.com/uri');
    }

    // [x] test mint standard token with & without donation
    // [x] test mint all tokens when paused and not paused
    // [x] test transfer standard when paused and not paused
    // [x] test mint premium with and without fees
    // [x] test non transferrable premium token
    // [x] test withdraw when paused and not paused
    function testMintAndTransferAllTokensWhenReceiverIsAccount() external {
        address minter = makeAddr('minter');

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(minter, address(0x00), minter, uint256(blog.STANDARD()), 1);
        vm.prank(minter);
        blog.mint();
        assertEq(blog.balanceOf(minter, uint256(blog.STANDARD())), 1);
        assertEq(blog.totalSupply(uint256(blog.STANDARD())), 1);

        assertFalse(blog.paused());

        vm.expectEmit(false, false, false, true);
        emit Paused(blog.owner());
        vm.prank(blog.owner());
        blog.pause();
        assertTrue(blog.paused());

        vm.prank(minter);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        blog.mint();
        assertEq(blog.balanceOf(minter, uint256(blog.STANDARD())), 1);

        vm.expectEmit(false, false, false, true);
        emit Unpaused(blog.owner());
        vm.prank(blog.owner());
        blog.unpause();
        assertFalse(blog.paused());

        uint256 initialContractBalance = address(blog).balance;

        startHoax(minter, 1 ether);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(minter, address(0x00), minter, uint256(blog.STANDARD()), 1);

        blog.mint{ value: 1 ether }();
        assertEq(blog.balanceOf(minter, uint256(blog.STANDARD())), 2);
        assertEq(blog.totalSupply(uint256(blog.STANDARD())), 2);

        uint256 afterMintContractBalance = initialContractBalance + 1 ether;
        assertEq(address(blog).balance, afterMintContractBalance);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(minter, minter, address(0x001), uint256(blog.STANDARD()), 1);
        blog.safeTransferFrom(minter, address(0x001), uint256(blog.STANDARD()), 1, '');
        assertEq(blog.balanceOf(minter, uint256(blog.STANDARD())), 1);
        assertEq(blog.balanceOf(address(0x001), uint256(blog.STANDARD())), 1);
        assertEq(blog.totalSupply(uint256(blog.STANDARD())), 2);

        vm.stopPrank();

        vm.startPrank(blog.owner());
        blog.pause();
        assertTrue(blog.paused());

        blog.withdraw(payable(address(0x002)));
        assertEq(address(blog).balance, 0);

        vm.stopPrank();

        address premiumMinter = makeAddr('premiumMinter');
        vm.deal(premiumMinter, 2 ether);

        uint256 premiumFee = blog.getPremiumFee();

        vm.prank(premiumMinter);

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        blog.mintPremium('https://example.com/premium-token');
        assertEq(blog.balanceOf(premiumMinter, uint256(blog.PREMIUM())), 0);

        vm.expectEmit(false, false, false, true);
        emit Unpaused(blog.owner());
        vm.prank(blog.owner());
        blog.unpause();
        assertFalse(blog.paused());

        vm.startPrank(premiumMinter);

        vm.expectRevert(abi.encodeWithSelector(IBlog.LessThanPremiumFee.selector, premiumFee));
        blog.mintPremium('https://example.com/premium-token');
        assertEq(blog.balanceOf(premiumMinter, uint256(blog.PREMIUM())), 0);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(premiumMinter, address(0x00), premiumMinter, uint256(blog.PREMIUM()), 1);

        vm.expectEmit(true, false, false, true);
        emit PremiumReceived(premiumMinter, 'https://example.com/premium-token');

        blog.mintPremium{ value: premiumFee }('https://example.com/premium-token');
        assertEq(blog.balanceOf(premiumMinter, uint256(blog.PREMIUM())), 1);
        assertEq(blog.totalSupply(uint256(blog.PREMIUM())), 1);

        vm.stopPrank();

        vm.prank(blog.owner());
        blog.withdraw(payable(address(0x004)));
        assertEq(address(blog).balance, 0);
    }

    // [x] test mint all tokens when receiver is contract
    // [x] test receiver if implementing IERC1155Receiver
    // [x] test receiver if not implementing IERC1155Receiver
    // [x] test emission of correct event when minting premium token
    // test withdraw premium fees when paused and not paused
    function testMintAndTransferAllTokensWhenReceiverIsContract() external {
        uint256 premiumFee = blog.getPremiumFee();

        uint256 contractInitialBalance = blog.balance();

        MockMinter mockMinter = new MockMinter(address(blog));
        MockMinterMissingHolder mockMinterMissingHolder = new MockMinterMissingHolder(address(blog));

        vm.prank(address(mockMinterMissingHolder));
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(mockMinterMissingHolder))
        );
        blog.mint();
        assertEq(blog.balanceOf(address(mockMinterMissingHolder), uint256(blog.STANDARD())), 0);

        vm.prank(address(blog.owner()));
        blog.pause();
        assertTrue(blog.paused());

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(address(mockMinterMissingHolder));
        blog.mint();
        assertEq(blog.balanceOf(address(mockMinterMissingHolder), uint256(blog.STANDARD())), 0);

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(address(mockMinterMissingHolder));
        blog.mintPremium('https://example.com/premium-token');
        assertEq(blog.balanceOf(address(mockMinterMissingHolder), uint256(blog.PREMIUM())), 0);

        vm.prank(address(blog.owner()));
        blog.unpause();
        assertFalse(blog.paused());

        vm.deal(address(mockMinter), 2 ether);
        vm.startPrank(address(mockMinter));

        vm.expectRevert(abi.encodeWithSelector(IBlog.LessThanPremiumFee.selector, premiumFee));
        blog.mintPremium('https://example.com/premium-token');
        assertEq(blog.balanceOf(address(mockMinter), uint256(blog.PREMIUM())), 0);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(mockMinter), address(0x00), address(mockMinter), uint256(blog.PREMIUM()), 1);

        vm.expectEmit(true, false, false, true);
        emit PremiumReceived(address(mockMinter), 'https://example.com/premium-token');

        blog.mintPremium{ value: premiumFee }('https://example.com/premium-token');
        assertEq(blog.balanceOf(address(mockMinter), uint256(blog.PREMIUM())), 1);
        assertEq(blog.totalSupply(uint256(blog.PREMIUM())), 1);
        assertEq(address(blog).balance, contractInitialBalance + premiumFee);

        vm.stopPrank();

        vm.startPrank(blog.owner());

        uint256 contractBalance = blog.balance();
        blog.pause();
        assertTrue(blog.paused());

        address withdrawer = makeAddr('withdrawer');
        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(withdrawer, contractBalance);

        blog.withdraw(payable(withdrawer));
        assertEq(address(blog).balance, 0);

        vm.stopPrank();
    }

    // [x] test upgrade to BlogV2 successfully
    // [x] test re-initialize contract
    // [x] test version upgraded
    // [x] test name immutable
    // [x] test withdraw modified to be accessible when not paused
    function testUpgradeToBlogV2Successfully() external {
        address owner = blog.owner();
        assertEq(blog.version(), '1.0.0');
        assertEq(blog.contractName(), 'Blog');

        vm.startPrank(owner);

        Upgrades.upgradeProxy(address(blog), 'BlogV2.sol', '', owner);

        address secondImplementation = Upgrades.getImplementationAddress(address(blog));
        assertTrue(secondImplementation != address(0));
        assertTrue(secondImplementation != implementation);
        console.log('Blog Upgraded Successfully Implementation Address:', secondImplementation);

        BlogV2 blogV2 = BlogV2(payable(address(blog)));

        // re-initialize the contract
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        blogV2.__Blog_init(owner, 1 ether, 'www.example.com/uri');

        // version
        assertEq(blogV2.version(), '1.1.0');

        // name
        assertEq(blogV2.contractName(), 'Blog');

        // withdraw modified to be accessible when not paused
        vm.deal(address(blogV2), 2 ether);
        assertEq(blogV2.balance(), 2 ether);

        blogV2.pause();
        assertTrue(blogV2.paused());

        address withdrawer = makeAddr('withdrawer');
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        blogV2.withdraw(payable(withdrawer));
        assertEq(blogV2.balance(), 2 ether);
        assertEq(withdrawer.balance, 0);

        blogV2.unpause();
        assertFalse(blogV2.paused());

        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(withdrawer, 2 ether);
        blogV2.withdraw(payable(withdrawer));
        assertEq(blogV2.balance(), 0);
        assertEq(withdrawer.balance, 2 ether);

        vm.stopPrank();
    }

}
