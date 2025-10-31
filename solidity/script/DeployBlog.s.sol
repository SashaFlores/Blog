// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ChainConfig } from './config/ChainConfig.sol';
import { Constants } from './config/Constants.sol';
import { Script, console } from 'forge-std/Script.sol';
import { Upgrades } from 'openzeppelin-foundry-upgrades/Upgrades.sol';
import { Blog } from 'src/Blog.sol';

contract DeployBlog is Script {

    function run() external returns (address blogProxy, address blogImplementation) {
        address initialOwner = vm.envAddress('OWNER');

        vm.startBroadcast();

        address proxy = Upgrades.deployUUPSProxy(
            'Blog.sol',
            abi.encodeCall(Blog.__Blog_init, (initialOwner, ChainConfig.getFeeByChainId(block.chainid), Constants.URI))
        );

        address implementation = Upgrades.getImplementationAddress(proxy);

        vm.stopBroadcast();

        return (proxy, implementation);
    }

}
