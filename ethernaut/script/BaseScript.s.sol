// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
pragma experimental ABIEncoderV2;

import {Script} from "forge-std/Script.sol";

abstract contract BaseScript is Script {
    address internal deployer;
    address internal contractAddress;

    function setUp() public virtual {
        deployer = vm.envAddress("SEPOIA_DEPLOYER");
    }

    modifier broadcaster() {
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }
}
