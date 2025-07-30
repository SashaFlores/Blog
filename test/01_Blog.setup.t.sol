// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/Script.sol";
import { Blog } from "../src/Blog.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";


contract BlogSetupTest is Test {
    Blog public blog;

    function setUp() public {
        blog = new Blog();
        blog.__Blog_init(msg.sender, 0.01 ether, "https://example.com/metadata/");
    }

    function test_initialOwner() public {
        assertEq(blog.owner(), address(this));
    }

    function test_premiumFee() public {
        assertEq(blog.getPremiumFee(), 0.01 ether);
    }


}