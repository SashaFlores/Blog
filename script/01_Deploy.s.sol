// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import { Blog } from "../src/Blog.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";


contract DeployScript is Script {

    function run() external returns (address, address) {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying Blog contract...");

        // Deploy the Blog contract with initial parameters
        address proxy = Upgrades.deployUUPSProxy(
            "Blog.sol",
            abi.encodeCall(Blog.__Blog_init, (msg.sender, 0.01 ether, "https://example.com/metadata/"))
        );

        address implementation = Upgrades.getImplementationAddress(proxy);

        vm.stopBroadcast();

        return (proxy, implementation);
    }

}