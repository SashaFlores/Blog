// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC1155 } from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import { Test, console } from 'forge-std/Test.sol';
import { Vm } from 'forge-std/Vm.sol';
import { Upgrades } from 'openzeppelin-foundry-upgrades/Upgrades.sol';
import { DeployBlog } from 'script/DeployBlog.s.sol';
import { ChainConfig } from 'script/config/ChainConfig.sol';
import { Constants } from 'script/config/Constants.sol';
import { Blog, IBlog } from 'src/Blog.sol';
// import { validateUpgradeSafety } from '@openzeppelin/upgrades-core';

event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
event Initialized(uint64 version);
event Upgraded(address indexed implementation);


contract BlogTest is Test {

    Blog public blog;


    function setUp() external {

        uint256 FORK_BLOCK_NUMBER = 8_015_500;

        vm.recordLogs();

        vm.createSelectFork(vm.rpcUrl('sepolia'), FORK_BLOCK_NUMBER);

        DeployBlog deployer = new DeployBlog();
        (address proxy,) = deployer.run();

        blog = Blog(payable(proxy));

    }

    function testDeployment_Success() external view {

        address initialOwner = vm.envAddress('OWNER');

        assertEq(blog.version(), '1.0.0');
        assertEq(blog.contractName(), 'Blog');
        assertEq(blog.owner(), initialOwner);
    }

    function testDeployment_EmitsEvents() external {
        Vm.Log[] memory entries = vm.getRecordedLogs();

      

    }

}
