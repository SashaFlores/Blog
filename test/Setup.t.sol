// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console} from "forge-std/Script.sol";
import { Blog } from "../src/Blog.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Vm } from "forge-std/Vm.sol";



contract SetupTest is Test {
    
    Blog public blog;


    address payable public nonOwner;
    address public premiumUser;
    address public nonPremiumUser;
    address public implementation;

    uint256 public initialPremiumFee = 0.05 ether;
    string public URI = "https://example.com/metadata/";


    function setUp() public {

        nonOwner = payable(address(0x001));
        premiumUser = payable(address(0x002));
        nonPremiumUser = payable(address(0x003));

        vm.recordLogs();

        // Deploy the Blog contract with initial parameters
        implementation = address(new Blog());
        address proxy = UnsafeUpgrades.deployUUPSProxy(
            implementation,
            abi.encodeCall(Blog.__Blog_init, (address(this), initialPremiumFee, URI))
        );

        // console.log("Blog Proxy Address:", proxy);
        // console.log("Blog Implementation Address:", implementation);

        blog = Blog(payable(proxy));

        // console.log("Blog Contract Address:", address(blog));
        // console.log("Setup Contract Address:", address(this));

    }
}