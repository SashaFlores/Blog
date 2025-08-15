// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test, console } from "forge-std/Test.sol";
import{ Blog } from "../../src/Blog.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Vm } from "forge-std/Vm.sol";


contract Setup is Test {

    Blog public blog;

    address public implementation;

    uint256 public premiumFee = 0.05 ether;
    string public URI = "https://example.com/metadata/";

    address public notOwner;
    address public premiumUser;
    address public standardUser;
    


    function setUp() public {

        notOwner = makeAddr("notOwner");
        premiumUser = makeAddr("premiumUser");
        standardUser = makeAddr("standardUser");

        
        vm.recordLogs();

        implementation = address(new Blog());
        address proxy = UnsafeUpgrades.deployUUPSProxy(
            implementation,
            abi.encodeCall(Blog.__Blog_init, (msg.sender, premiumFee, URI))
        );

        blog = Blog(payable(proxy));

        // console.log("Blog contract address", address(blog));
        // console.log("Test address", address(this));
        // console.log("Owner Address", msg.sender);
    }
}