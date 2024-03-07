// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
pragma experimental ABIEncoderV2;

import {Script} from "forge-std/Script.sol";

abstract contract BaseScript is Script {
    address internal deployer;
    address internal contractAddress;
    string internal mnemonic;

    function setUp() public virtual {
        deployer = vm.envAddress("DEPLOYER_ADDRESS");
    }

    modifier broadcaster() {
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }
}
