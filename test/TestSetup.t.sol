// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { Blog } from "../src/Blog.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Vm } from "forge-std/Vm.sol";


contract TestSetupTest is Test {


    function test_DeploymentEmitsExpectedEvents() public {
        vm.recordLogs();

        address implementation = address(new Blog());
        address proxy = UnsafeUpgrades.deployUUPSProxy(
            implementation,
            abi.encodeCall(Blog.__Blog_init, (address(this), 0.01 ether, "https://example.com/metadata/"))
        );


        Vm.Log[] memory entries = vm.getRecordedLogs();


        // Track events
        bool ownershipTransferredFound;
        bool upgradedFound;
        bool initializedFound;

        for (uint256 i = 0; i < entries.length; ++i) {
            Vm.Log memory log = entries[i];

            // OwnershipTransferred
            if (
                log.topics.length == 3 &&
                log.topics[0] == keccak256("OwnershipTransferred(address,address)") &&
                address(uint160(uint256(log.topics[1]))) == address(0) &&
                address(uint160(uint256(log.topics[2]))) == address(this)
            ) {
                ownershipTransferredFound = true;
            }

            // Upgraded
            if (
                log.topics.length == 2 &&
                log.topics[0] == keccak256("Upgraded(address)") &&
                address(uint160(uint256(log.topics[1]))) == implementation
            ) {
                upgradedFound = true;
            }

            // Initialized
            if (
                log.topics.length == 1 &&
                log.topics[0] == keccak256("Initialized(uint64)") &&
                abi.decode(log.data, (uint64)) == 1
            ) {
                initializedFound = true;
            }
        }

        assertTrue(ownershipTransferredFound, "OwnershipTransferred event not found");
        assertTrue(upgradedFound, "Upgraded event not found");
        assertTrue(initializedFound, "Initialized event not found");

    }
}