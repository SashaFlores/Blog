// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC1155 } from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import { Test, console } from 'forge-std/Test.sol';
import { Upgrades } from 'openzeppelin-foundry-upgrades/Upgrades.sol';
import { DeployBlog } from 'script/DeployBlog.s.sol';
import { ChainConfig } from 'script/config/ChainConfig.sol';
import { Constants } from 'script/config/Constants.sol';
import { Blog, IBlog } from 'src/Blog.sol';


contract BlogTest is Test {

    Blog public blog;


    function setUp() external {
        uint256 FORK_BLOCK_NUMBER = 9_015_500;

        vm.createSelectFork(vm.rpcUrl('sepolia'), FORK_BLOCK_NUMBER);

        DeployBlog deployer = new DeployBlog();
        (address proxy,) = deployer.run();

        blog = Blog(payable(proxy));

    }

    function testDeployment_Success() external view {

        assertEq(blog.version(), '1.0.0');
        assertEq(blog.contractName(), 'Blog');
        console.log('BLOG OWNER IS:', blog.owner());
    }

}
