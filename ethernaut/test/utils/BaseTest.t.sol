// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
pragma experimental ABIEncoderV2;

import {Test} from "forge-std/Test.sol";

abstract contract BaseTest is Test {
    address internal deployer;
    address internal contractAddress;
    string internal mnemonic;

    function setUp() public virtual {
       deployer = vm.envAddress("SEPOIA_DEPLOYER");
    }

    modifier broadcaster() {
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }
}