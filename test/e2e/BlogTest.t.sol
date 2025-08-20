// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC1155 } from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import { PausableUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import { Test, console } from 'forge-std/Test.sol';
import { Vm } from 'forge-std/Vm.sol';
import { Upgrades } from 'openzeppelin-foundry-upgrades/Upgrades.sol';
import { DeployBlog } from 'script/DeployBlog.s.sol';
import { Blog, IBlog } from 'src/Blog.sol';



event Upgraded(address indexed implementation);
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
event Initialized(uint64 version);


event TransferSingle(
    address indexed operator,
    address indexed from,
    address indexed to,
    uint256 id,
    uint256 value
);
event Paused(address account);
event Unpaused(address account);
event FundsReceived(address indexed sender, uint256 amount);
error NonTransferrable();
// error EnforcedPause();
error LessThanPremiumFee(uint256 requiredFee);



contract BlogTest is Test {

    Blog public blog;

    address implementation;


    function setUp() external {

        uint256 FORK_BLOCK_NUMBER = 8_015_500;

        vm.recordLogs();

        vm.createSelectFork(vm.rpcUrl('sepolia'), FORK_BLOCK_NUMBER);

        DeployBlog deployer = new DeployBlog();
        (address proxy, address impl) = deployer.run();

        blog = Blog(payable(proxy));
        implementation = impl;
    }

    function testDeployment_Success() external view {

        address initialOwner = vm.envAddress('OWNER');

        assertEq(blog.version(), '1.0.0');
        assertEq(blog.contractName(), 'Blog');
        assertEq(blog.owner(), initialOwner);
    }

    function testDeployment_EmitsEvents() external {
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // check length of expected logs
        assertEq(logs.length, 4);

        // check logs signatures
        bytes32 upgradedEventSignature = keccak256('Upgraded(address)');
        bytes32 ownershipTransferredEventSignature = keccak256('OwnershipTransferred(address,address)');
        bytes32 initializedEventSignature = keccak256('Initialized(uint64)'); 

        assertEq(logs[0].topics[0], initializedEventSignature);
        assertEq(logs[1].topics[0], upgradedEventSignature);
        assertEq(logs[2].topics[0], ownershipTransferredEventSignature);
        assertEq(logs[3].topics[0], initializedEventSignature);

        // check logs emitters' addresses
        assertEq(logs[0].emitter, implementation);
        assertEq(logs[1].emitter, address(blog));
        assertEq(logs[2].emitter, address(blog));
        assertEq(logs[3].emitter, address(blog));

        // check logs topic and data
        assertEq(abi.decode(logs[0].data, (uint64)), type(uint64).max); 
        assertEq(logs[1].topics[1], bytes32(uint256(uint160((implementation)))));
        assertEq(logs[2].topics[1], bytes32(uint256(uint160(address(0x00)))));
        assertEq(logs[2].topics[2], bytes32(uint256(uint160(blog.owner()))));
        assertEq(abi.decode(logs[3].data, (uint64)), 1);
    }

    // [x] test mint standard token with & without donation 
    // [x] test mint standard token paused and not paused 
    // [x] test transfer when paused and not paused
    // [x] test withdraw when paused and not paused
    function testMintAndTransferStandardToken() external {

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

        blog.mint{value: 1 ether}();
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
    }


    // test mint premium token if no fess paid and with fees 
    // and when paused and no transfer is allowed at all times and the event of uri is emitted correctly
    // test withdraw premium fees when paused and not paused


    // test when receive is called event is emitted correctly and the balance is updated

}
