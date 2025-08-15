// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import { Blog } from "../src/Blog.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";



contract DeployScript is Script {


    function run() external returns (address blogProxy, address blogImplementation) {


        console.log("Deploying Blog contract...");

        vm.startBroadcast();

        address proxy = Upgrades.deployUUPSProxy(
            "Blog.sol",
            abi.encodeCall(Blog.__Blog_init, (msg.sender, 0.01 ether, "https://example.com/metadata/"))
        );

        address implementation = Upgrades.getImplementationAddress(proxy);

        vm.stopBroadcast();

        return (proxy, implementation);
    }

}