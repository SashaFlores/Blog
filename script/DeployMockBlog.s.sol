// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { MockBlogFailureUpgrade } from './mocks/MockBlogFailureUpgrade.sol';
import { MockBlogSuccessfulUpgrade } from './mocks/MockBlogSuccessfulUpgrade.sol';
import { Script, console } from 'forge-std/Script.sol';
import { Upgrades } from 'openzeppelin-foundry-upgrades/Upgrades.sol';

contract DeployMockBlog is Script {

    function run() external { }

}
